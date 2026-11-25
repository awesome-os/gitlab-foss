# frozen_string_literal: true

module Gitlab
  module Middleware
    # Runs Labkit::RateLimit alongside Rack::Attack during the migration off the
    # legacy stack. Per-cohort wip flags drive three states, mirroring
    # Gitlab::ApplicationRateLimiter::LabkitAdapter:
    #
    #   shadow off              : labkit does not run; Rack::Attack alone decides.
    #   shadow on, enforce off  : labkit runs, but its decision is never acted on.
    #   shadow on, enforce on   : labkit additionally blocks. On a block whose cohort
    #                             enforces it renders the byte-identical legacy 429
    #                             and short-circuits; otherwise the request falls
    #                             through to Rack::Attack, which still enforces.
    #
    # PlanRules also starts it, independently of the cohorts. The cost-mode
    # limiters (Limiters::COST_MODE) run with the rest: peeked on the way in, and
    # charged a measurement of the request on the way out.
    #
    # Mounted directly above Rack::Attack (see config/application.rb), so it wraps it
    # and observes every request after Warden has resolved auth. On the way in it
    # builds a ClassifiedRequest of raw request facts and runs every limiter's full,
    # ordered rule set over them (cohort gates enforcement, not which rules exist).
    # Each limiter returns its first matching rule's decision; labkit blocks the
    # request when any of those decisions is a block whose cohort enforces. Once
    # fully enforced, on the way back up it adds the proactive RateLimit-* headers to
    # non-429 responses, taking over from RackAttackHeaders, which the safelist leaves
    # with nothing to read.
    #
    # The middleware blocks only when an enforcing cohort's rule blocks, or when a
    # rule with no registry entry (a plan or cost rule) blocks, otherwise it never
    # blocks.
    # The request's own errors propagate (@app.call is not wrapped), and so do ours
    # on the way in: the flag reads and request.labkit_facts can reach Redis and the
    # database, and if those are down the request fails anyway. The exception is a
    # regex timeout in the facts, which fails open as Labkit does. Work after the
    # decision (instrumentation, block logging and counting, outbound headers) is
    # guarded: in production it must never turn a good response into a 500.
    #
    # Collaborators are referenced lazily inside methods rather than via class-body
    # constants: this file is required from config/application.rb before
    # Zeitwerk autoloading is active, so it must not resolve autoloaded siblings at
    # load time.
    class LabkitRackRateLimit
      BLOCK_MESSAGE = 'Rate_Limit_Block'
      COUNT_HEADERS = %w[RateLimit-Limit RateLimit-Observed RateLimit-Remaining].freeze
      # The logging team set these to keep lines low on gprd. Raise them with that team.
      BLOCK_SUMMARY_INTERVAL_SECONDS = 900
      BLOCK_SUMMARY_MAX_PAIRS = 5

      # Not a constant, for the autoload reason above. The initializer first calls this on
      # worker start, before any request. The flush thread has no request store, so the
      # logger is built once: AuthLogger.info would reopen the log file for every line.
      def self.block_summary
        @block_summary ||= ::Labkit::RateLimit::BlockSummary.new(
          logger: ::Gitlab::AuthLogger.build,
          interval: BLOCK_SUMMARY_INTERVAL_SECONDS,
          max_pairs: BLOCK_SUMMARY_MAX_PAIRS
        )
      end

      def initialize(app)
        @app = app
      end

      def call(env)
        return @app.call(env) unless any_active_cohort? || plan_rules.active?

        request = build_request(env)
        context = classify(request)
        return @app.call(env) unless context

        decision = run(request, context)

        return decision[:response] if decision[:response]

        status, headers, body = charge_cost_budget(context) { @app.call(env) }

        guard { annotate_rate_limit_headers(status, headers, decision[:results]) }

        [status, headers, body]
      end

      private

      # Counted with the labels Labkit gives a check or peek that fails open, so the
      # fail-open alert sees it, although no limiter ran.
      def classify(request)
        with_isolated_throttle_instrumentation { request.labkit_facts }
      rescue Regexp::TimeoutError => e
        # Reported about once per process, as in block_endpoint. The counters below carry the volume.
        ::Gitlab::ErrorTracking.track_exception(e) unless @facts_timeout_reported
        @facts_timeout_reported = true

        limiters.all.each_key do |name|
          if limiters.cost_mode?(name)
            ::Labkit::RateLimit::Metrics.safe_increment(:peeks_total, { rate_limiter: name, error: 'true' })
          else
            ::Labkit::RateLimit::Metrics.safe_increment(
              :checks_total, { rate_limiter: name, action: 'allow', matched: 'false', error: 'true' }
            )
          end
        end

        nil
      end

      # Inbound: run the request facts through every limiter's full ordered rule
      # set. Each limiter returns its first matching rule's result (an :allow for a
      # bypassed/skipped/unmatched request, otherwise the matched rule's decision).
      # A cost-mode limiter is peeked, not checked: its cost is only known once the
      # request finishes. Returns those results (read again on the way out) and the
      # byte-identical 429 to return in place of calling the app (nil unless an
      # enforcing rule blocks).
      def run(request, context)
        checks = limiters.all.to_h do |name, limiter|
          [name, limiters.cost_mode?(name) ? limiter.peek(context) : limiter.check(context, rule_context: context)]
        end
        results = checks.values
        blocked = enforced_block(results)
        decision = { results: results, response: blocked && throttled_response(blocked) }

        # Each post-decision step has its own guard, so in production a raise in one
        # cannot drop the 429 or skip the steps after it.
        guard { ::Gitlab::Instrumentation::RateLimitState.track(checks) }

        # Its own guard, same reason as above. Must follow track: the line reads the
        # state that call records.
        guard { log_block(blocked, context) } if blocked

        guard { count_block(blocked, request) } if blocked

        decision
      end

      # Outbound: charges each cost-mode limiter the measurement it declares. In
      # ensure, so a request that raises still pays.
      def charge_cost_budget(context)
        started_at = ::Gitlab::Metrics::System.monotonic_time
        yield
      ensure
        guard do
          measurement = { duration_s: ::Gitlab::Metrics::System.monotonic_time - started_at }

          limiters.all.each_pair do |name, limiter|
            next unless limiters.cost_mode?(name)

            limiter.check(context, cost: measurement.fetch(limiters.cost_measurement(name)))
          end
        end
      end

      # Outbound: proactive RateLimit-* headers for non-429 responses (a 429 already
      # carries its own), added only once labkit fully owns enforcement - until then
      # Rack::Attack still evaluates throttles and RackAttackHeaders builds these.
      # Built from the counted evaluations, not each limiter's reported result (an
      # under-limit result reports the claim rule, which carries no counter info).
      def annotate_rate_limit_headers(status, headers, results)
        return if status == 429 || !registry.fully_enforced?

        evaluation = most_constraining_enforced(results)
        return unless evaluation

        rate_limit_headers = ::Gitlab::RackAttack::RequestThrottleData
          .from_labkit_result(name: throttle_name_for(evaluation.rule.name), result: evaluation)
          &.common_response_headers

        headers.merge!(rate_limit_headers) if rate_limit_headers
      end

      # The most constraining evaluation across all limiters, skipping :log rules: a
      # :log rule never enforces, so its quota is never advertised. Concealed rules
      # are skipped too. Ties keep the earlier evaluation, as Enumerable#min would.
      def most_constraining_enforced(results)
        evaluation = nil

        results.each do |result|
          result.evaluations.each do |counted|
            next if counted.rule.action == :log || concealed_rules.key?(counted.rule.name)

            evaluation = counted if evaluation.nil? || counted < evaluation
          end
        end

        evaluation
      end

      # The first blocking rule that enforces: a registry rule whose cohort enforces,
      # or a plan rule (no registry entry), which enforces whenever it is a :limit rule.
      def enforced_block(results)
        results.find do |result|
          # An unmatched or synthetic-allow result carries no rule, so its cohort can
          # only be looked up once blocked? has confirmed a matched throttle blocked
          # (a block always carries its rule). Testing blocked? first also preserves
          # the short-circuit the &&-chain relied on before entry was hoisted out.
          next false unless blocked?(result)

          entry = entry_for_rule(result.rule.name)
          entry.nil? || registry.enforce_enabled?(entry.cohort)
        end
      end

      # The byte-identical legacy 429. The counter was already incremented in the
      # limiter check, so reading the decision here never double-counts. Mirrors
      # Gitlab::RackAttack's throttled_responder so a promoted throttle is
      # indistinguishable from the legacy stack to clients.
      #
      # A concealed rule's 429 carries its shared name and only the reset headers, so
      # it doesn't say which of the rules sharing that name blocked.
      def throttled_response(blocked)
        concealed_name = concealed_rules[blocked.rule.name]

        headers = ::Gitlab::RackAttack::RequestThrottleData
          .from_labkit_result(name: concealed_name || throttle_name_for(blocked.rule.name), result: blocked)
          &.throttled_response_headers
        headers = headers&.except(*COUNT_HEADERS) if concealed_name

        [429, { 'Content-Type' => 'text/plain' }.merge(headers || {}), [::Gitlab::Throttle.rate_limiting_response_text]]
      end

      # A blocked request never reaches a controller, so lograge writes nothing for
      # it. No meta.caller_id or meta.feature_category either: the controller that
      # pushes those never runs.
      #
      # One line when a client first crosses a rule's limit, then only at 2x, 4x, 8x
      # of it. The trigger is the counter labkit already returned, so a blocked
      # request costs no extra Redis call: load there during an attack is what makes
      # the limiter fail open and let more requests through.
      def log_block(blocked, context)
        info = blocked.info
        return unless info && escalation_point?(info)

        rule = blocked.rule

        ::Gitlab::AuthLogger.error(
          {
            message: BLOCK_MESSAGE,
            status: 429,
            matched: throttle_name_for(rule.name),
            rule: rule.name,
            # Same keys as the legacy Rack_Attack line, so one saved search reads both.
            # remote_ip is unconditional: counted_by holds the IP only for IP-keyed rules.
            remote_ip: context[:remote_ip],
            path: context[:path],
            method: context[:method],
            limit: info.resolved_limit,
            period_s: info.resolved_period,
            count: info.count.to_i,
            counted_by: counted_by(rule, context)
          }.merge(::Gitlab::Instrumentation::RateLimitState.payload)
        )
      end

      # A blocked request never reaches the app, so RequestsRackMiddleware records it as
      # endpoint_id "unknown". This counts it against the endpoint it was headed for.
      def count_block(blocked, request)
        return unless ::Feature.enabled?(
          :rate_limiter_endpoint_block_summary, ::Feature.current_request, type: :gitlab_com_derisk
        )

        endpoint_id, feature_category = block_endpoint(request)
        rack_metrics = ::Gitlab::Metrics::RequestsRackMiddleware

        # The same defaults the request SLIs record, so log filters match the metrics.
        self.class.block_summary.add(
          endpoint_id: endpoint_id || rack_metrics::ENDPOINT_MISSING,
          rule: blocked.rule.name,
          feature_category: feature_category.presence || rack_metrics::FEATURE_CATEGORY_DEFAULT
        )
      end

      # Reported about once per process: a path that raises would raise on every block of an attack.
      def block_endpoint(request)
        endpoint_resolver.resolve(request.env)
      rescue StandardError => e
        ::Gitlab::ErrorTracking.track_exception(e) unless @endpoint_error_reported
        @endpoint_error_reported = true
        [nil, nil]
      end

      # The first block is one past the limit. After that only the doublings, so a
      # client sending many times the limit produces a handful of lines rather than
      # one for every limit's worth of requests.
      # count is a Float and a count_distinct rule can report a fractional one, so
      # both bounds are explicit: without them a count that truncates to the limit
      # divides into a multiple of 1, which reads as a doubling and logs every
      # blocked request.
      def escalation_point?(info)
        count = info.count.to_i
        limit = info.resolved_limit.to_i
        return false unless limit > 0
        return false if count <= limit
        return true if count == limit + 1

        multiple, over = count.divmod(limit)
        over == 0 && multiple > 1 && (multiple & (multiple - 1)) == 0
      end

      # The bucket labkit counted, stringified as labkit keys it: a query param such
      # as aid can parse to a Hash or an Array, and Elasticsearch drops a line whose
      # field shape differs from the index mapping.
      def counted_by(rule, context)
        rule.characteristics.index_with { |characteristic| context[characteristic]&.to_s }
      end

      # The RateLimit-Name for a rule: the backing throttle's name (Entry#name), not
      # the rule name, so a registry rule's headers stay byte-identical to the legacy
      # Rack::Attack responder, a rule with no entry carries its own name.
      def throttle_name_for(rule_name)
        entry_for_rule(rule_name)&.name || rule_name
      end

      # A dry-run throttle's rule is :log, so it never reports :block; the synthetic
      # bypass/skip/runner/claim rules and an unmatched request are :allow. So neither
      # a tracked-only throttle nor a short-circuited request is ever read as a block.
      def blocked?(result)
        result.action == :block
      end

      # The throttle Entry a matched Labkit rule name resolves to, memoized on first
      # use (the first request, past initialization, so the required
      # middleware never resolves its registry sibling at load time). Keyed by Labkit
      # rule name, from which both the enforce cohort (Entry#cohort) and the 429 header
      # name (Entry#name, the backing throttle) resolve. Synthetic and plan rules have
      # no entry: a synthetic rule never blocks, and a plan rule needs no cohort.
      def entry_for_rule(rule_name)
        @entries_by_rule ||= registry.by_rule_name
        @entries_by_rule[rule_name]
      end

      # ClassifiedRequest#labkit_facts no longer writes
      # Gitlab::Instrumentation::Throttle.safelist: it computes the requester
      # discriminator from the auth primitive rather than throttled_identifer, so it
      # carries no instrumentation side effect. This guard is now defensive - if any
      # fact the shadow reads were to touch the safelist again, it is saved and
      # restored (only when actually changed) so the shadow leaves the real request's
      # instrumentation untouched; Rack::Attack sets the safelist itself via its own
      # auth path regardless.
      def with_isolated_throttle_instrumentation
        instrumentation = ::Gitlab::Instrumentation::Throttle
        original = instrumentation.safelist
        yield
      ensure
        instrumentation.safelist = original unless instrumentation.safelist == original
      end

      def any_active_cohort?
        registry.cohorts.any? { |cohort| registry.shadow_enabled?(cohort) }
      end

      # The request that classifies itself for labkit, built from a dup of the env
      # with PATH_INFO normalized the way Rack::Attack normalizes it before
      # classifying (we run first), to avoid a spurious path divergence without
      # mutating the shared env. We call ActionDispatch::Journey::Router::Utils
      # directly (what Rack::Attack::PathNormalizer resolves to in a Rails app).
      # ClassifiedRequest is the same shape as Rack::Attack::Request but carries no
      # Rack::Attack dependency.
      def build_request(env)
        shadow_env = env.dup
        shadow_env['PATH_INFO'] = ::ActionDispatch::Journey::Router::Utils.normalize_path(shadow_env['PATH_INFO'])
        ::Gitlab::RackAttack::LabkitRateLimit::ClassifiedRequest.new(shadow_env)
      end

      # Raises in development and test so our bugs surface. In production it tracks
      # and returns nil, so the request keeps the decision it already has.
      def guard
        yield
      rescue StandardError => e
        ::Gitlab::ErrorTracking.track_and_raise_for_dev_exception(e)
        nil
      end

      def registry
        ::Gitlab::RackAttack::LabkitRateLimit::ThrottleRegistry
      end

      def endpoint_resolver
        ::Gitlab::RackAttack::LabkitRateLimit::EndpointResolver.instance
      end

      def limiters
        ::Gitlab::RackAttack::LabkitRateLimit::Limiters
      end

      def plan_rules
        ::Gitlab::RateLimit::PlanRules
      end

      def concealed_rules
        plan_rules.concealed_rules
      end
    end
  end
end
