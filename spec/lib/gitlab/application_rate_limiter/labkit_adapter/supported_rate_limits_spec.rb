# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::ApplicationRateLimiter::LabkitAdapter::SupportedRateLimits,
  :clean_gitlab_redis_rate_limiting, feature_category: :rate_limiting do
  let(:cost_mode_keys) do
    %i[
      main_db_duration_limit_per_worker
      ci_db_duration_limit_per_worker
      sec_db_duration_limit_per_worker
      glql_db_seconds_by_query_sha
      glql_db_seconds_by_user
      glql_db_seconds_by_ip
      glql_duo_db_seconds_by_user
      click_house_read_bytes_by_user
      click_house_read_rows_by_user
      click_house_duration_s_by_user
    ]
  end

  let(:threshold_from_caller_keys) do
    %i[
      web_hook_calls
      web_hook_calls_low
      web_hook_calls_mid
      organization_web_hook_calls
      integration_executions
      integration_executions_datadog
      service_desk_outbound_emails_per_hour
      service_desk_outbound_emails_per_day
      service_desk_external_participants_per_day
    ]
  end

  describe 'registry coverage' do
    it 'builds limiters for every registered rule' do
      expect(described_class.all.keys).to match_array(described_class.rules.keys)
    end

    it 'registers valid labkit rate-limit entries', :aggregate_failures do
      expect(described_class.all).not_to be_empty

      described_class.all.to_a.each do |key, limiter|
        rule = described_class.rule_for(key)

        expect(limiter).to be_a(::Labkit::RateLimit::Limiter), "#{key} limiter must be a Labkit limiter"
        expect(rule).to be_a(::Labkit::RateLimit::Rule), "#{key} rule must be a Labkit rule"
        expect(rule.name).not_to be_empty, "#{key} rule name must not be empty"
        expect(rule.name).to start_with('limit_'), "#{key} rule name must start with limit_"
        expect(rule.characteristics).to be_an(Array), "#{key} characteristics must be an Array"
        expect(rule.characteristics).not_to be_empty, "#{key} characteristics must not be empty"
        expect(rule.characteristics).to all(be_a(Symbol)), "#{key} characteristics must be Symbols"
        expect(rule.action).to eq(:limit), "#{key} action must be :limit"
      end
    end

    it 'requires limit and period unless the entry documents why they are caller-supplied', :aggregate_failures do
      described_class.rules.to_a.each do |key, rule|
        if cost_mode_keys.include?(key)
          expect(described_class.cost_mode?(key)).to be(true), "#{key} must be marked as cost_mode"
          next
        end

        if threshold_from_caller_keys.include?(key)
          expect(rule.limit).to respond_to(:call), "#{key} must define a caller-aware limit"
          expect(rule.period).to be_present, "#{key} must define a period"
          expect(described_class.cost_mode?(key)).to be(false),
            "#{key} must not be both threshold-from-caller and cost_mode"
          next
        end

        expect(rule.limit).to be_present,
          "#{key} must define a limit unless it is an explicit special case"
        expect(rule.period).to be_present,
          "#{key} must define a period unless it is an explicit special case"
      end
    end
  end

  describe 'limiter names' do
    # The contract names each key applimiter_<key>, so the key has to leave room
    # for the prefix under the schema's 64-character cap.
    it 'gives every key a limiter name the contract schema accepts' do
      rejected = described_class.rules.keys.map { |key| described_class.limiter_name(key) }
        .grep_v(Labkit::RateLimit::Config::Schema::NAME)

      expect(rejected).to be_empty
    end
  end

  describe '.staged_rule' do
    subject(:staged) do
      described_class.staged_rule(
        enforce: gate,
        name: 'limit_staged_by_user',
        characteristics: %i[user],
        limit: 1,
        period: 1.minute,
        match: { endpoint: 'create' }
      )
    end

    let(:gate) { ->(_scope) { false } }

    it 'builds a :limit rule that matches only when enforced', :aggregate_failures do
      rule = staged.rule

      expect(rule.name).to eq('limit_staged_by_user')
      expect(rule.action).to eq(:limit)
      expect(rule.characteristics).to eq(%i[user])
      expect(rule.match.keys).to contain_exactly(:endpoint, described_class::ENFORCED_FACT)
      expect(rule.match[described_class::ENFORCED_FACT].match?(true)).to be(true)
      expect(rule.match[described_class::ENFORCED_FACT].match?(false)).to be(false)
    end

    it 'builds a :log twin with the same counting attributes that matches only when not enforced',
      :aggregate_failures do
      log_rule = staged.log_rule

      expect(log_rule.name).to eq('limit_staged_by_user_log')
      expect(log_rule.action).to eq(:log)
      expect(log_rule.characteristics).to eq(staged.rule.characteristics)
      expect(log_rule.limit).to eq(staged.rule.limit)
      expect(log_rule.period).to eq(staged.rule.period)
      expect(log_rule.match.keys).to contain_exactly(:endpoint, described_class::ENFORCED_FACT)
      expect(log_rule.match[described_class::ENFORCED_FACT].match?(false)).to be(true)
      expect(log_rule.match[described_class::ENFORCED_FACT].match?(true)).to be(false)
    end

    it 'keeps the enforce gate' do
      expect(staged.enforce).to be(gate)
    end

    it 'rejects an explicit action' do
      expect do
        described_class.staged_rule(
          enforce: gate, action: :log, name: 'limit_staged_by_user',
          characteristics: %i[user], limit: 1, period: 1.minute
        )
      end.to raise_error(ArgumentError, 'staged_rule sets action itself')
    end

    it 'rejects a gate that does not take the scope' do
      expect do
        described_class.staged_rule(
          enforce: -> { true }, name: 'limit_staged_by_user',
          characteristics: %i[user], limit: 1, period: 1.minute
        )
      end.to raise_error(ArgumentError, 'enforce must take the scope')
    end
  end

  context 'with a staged registry entry' do
    let(:user) { build_stubbed(:user) }
    let(:gate) { ->(_scope) { false } }
    let(:staged) do
      described_class.staged_rule(
        enforce: gate,
        name: 'limit_staged_by_user',
        characteristics: %i[user],
        limit: 1,
        period: 1.minute
      )
    end

    before do
      allow(described_class).to receive(:rule_definitions).and_wrap_original do |original|
        original.call.merge(staged_key: staged)
      end
      described_class.reset!
    end

    after do
      described_class.reset!
    end

    describe '.reset!' do
      it 'clears the memoized registry so the next read builds it again' do
        described_class.staged_rules
        described_class.reset!
        described_class.staged_rules

        expect(described_class).to have_received(:rule_definitions).twice
      end
    end

    it 'registers the :limit rule as the rule for the key' do
      expect(described_class.rule_for(:staged_key)).to eq(staged.rule)
    end

    it 'resolves the limit and period from the :limit rule', :aggregate_failures do
      expect(described_class.limit_for(:staged_key)).to eq(1)
      expect(described_class.period_for(:staged_key)).to eq(1.minute)
    end

    describe '.staged_rules' do
      it 'contains only staged entries', :aggregate_failures do
        expect(described_class.staged_rules).to include(staged_key: staged)
        expect(described_class.staged_rules.values).to all(be_a(described_class::StagedRule))
      end

      it 'shares one registry build with .rules', :aggregate_failures do
        expect(described_class.staged_rules[:staged_key].rule).to be(described_class.rules[:staged_key])
        expect(described_class).to have_received(:rule_definitions).once
      end
    end

    describe '.staged?' do
      it 'returns true for a staged key' do
        expect(described_class.staged?(:staged_key)).to be(true)
      end

      it 'returns false for a key registered with Rule.new' do
        expect(described_class.staged?(:pipelines_create)).to be(false)
      end
    end

    describe '.enforced?' do
      let(:gate) { instance_double(Proc, call: true, arity: 1) }

      it 'calls the gate with the caller scope', :aggregate_failures do
        expect(described_class.enforced?(:staged_key, { user: user })).to be(true)
        expect(gate).to have_received(:call).with({ user: user })
      end
    end

    describe '.limiter_for' do
      let(:limiter) { described_class.limiter_for(:staged_key) }

      it 'builds the bypass rule, the :limit rule, then the :log twin' do
        allow(::Labkit::RateLimit::Limiter).to receive(:new).and_call_original

        limiter

        expect(::Labkit::RateLimit::Limiter).to have_received(:new).with(hash_including(
          rules: [an_object_having_attributes(name: 'staged_key_bypass'), staged.rule, staged.log_rule]
        ))
      end

      context 'when not enforced' do
        it 'counts on the log twin and does not block', :aggregate_failures do
          limiter.check({ user: user.id, described_class::ENFORCED_FACT => false })
          result = limiter.check({ user: user.id, described_class::ENFORCED_FACT => false })

          expect(result.rule.name).to eq('limit_staged_by_user_log')
          expect(result.exceeded?).to be(true)
          expect(result.block?).to be(false)
        end
      end

      context 'when enforced' do
        it 'counts on the :limit rule and blocks', :aggregate_failures do
          limiter.check({ user: user.id, described_class::ENFORCED_FACT => true })
          result = limiter.check({ user: user.id, described_class::ENFORCED_FACT => true })

          expect(result.rule.name).to eq('limit_staged_by_user')
          expect(result.block?).to be(true)
        end
      end
    end

    describe 'through Gitlab::ApplicationRateLimiter.throttled?' do
      let(:gate) { ->(_scope) { true } }

      it 'throttles once the staged key is over its limit when enforced', :aggregate_failures do
        expect(Gitlab::ApplicationRateLimiter.throttled?(:staged_key, scope: { user: user })).to be(false)
        expect(Gitlab::ApplicationRateLimiter.throttled?(:staged_key, scope: { user: user })).to be(true)
      end
    end
  end

  describe 'staged twin names' do
    it 'does not collide with any registered rule name' do
      names = described_class.rules.values.map(&:name)

      expect(names.map { |name| "#{name}_log" } & names).to be_empty
    end
  end

  describe '.limiter_for' do
    it 'returns a labkit limiter for a registered key' do
      expect(described_class.limiter_for(:pipelines_create)).to be_a(::Labkit::RateLimit::Limiter)
    end

    it 'caches the limiter for a registered key' do
      limiter = described_class.limiter_for(:pipelines_create)

      expect(described_class.limiter_for(:pipelines_create)).to be(limiter)
    end

    it 'raises KeyError for an unregistered key' do
      expect { described_class.limiter_for(:not_a_registered_key) }.to raise_error(KeyError)
    end

    it 'builds a limiter that can check using the registered rule' do
      user = build_stubbed(:user)
      limiter = described_class.limiter_for(:users_get_by_id)

      allow(Gitlab::CurrentSettings.current_application_settings)
        .to receive(:users_get_by_id_limit).and_return(1)

      expect(limiter.check({ user: user.id }).exceeded?).to be(false)
      expect(limiter.check({ user: user.id }).exceeded?).to be(true)
    end

    describe 'the synthetic bypass rule' do
      it "skips before the real rule when bypass_header is '1', without touching Redis", :aggregate_failures do
        user = build_stubbed(:user)
        limiter = described_class.limiter_for(:users_get_by_id)

        allow(Gitlab::CurrentSettings.current_application_settings)
          .to receive(:users_get_by_id_limit).and_return(1)

        result = limiter.check({ user: user.id, bypass_header: '1' })

        expect(result.skipped?).to be(true)
        expect(result.rule.name).to eq('users_get_by_id_bypass')
        expect(result.exceeded?).to be(false)
      end

      it "never matches when bypass_header is absent, nil, or not exactly '1'", :aggregate_failures do
        user = build_stubbed(:user)
        limiter = described_class.limiter_for(:users_get_by_id)

        expect(limiter.check({ user: user.id }).skipped?).to be(false)
        expect(limiter.check({ user: user.id, bypass_header: nil }).skipped?).to be(false)
        expect(limiter.check({ user: user.id, bypass_header: '0' }).skipped?).to be(false)
        # Regression guard: the match is exact-string equality, not truthiness
        # (this field used to be a Boolean before it carried the raw header
        # value): a caller passing the old Boolean shape must not bypass.
        expect(limiter.check({ user: user.id, bypass_header: true }).skipped?).to be(false)
        expect(limiter.check({ user: user.id, bypass_header: 'true' }).skipped?).to be(false)
      end

      it 'skips on #peek too, without reading or affecting the real rule counter', :aggregate_failures do
        user = build_stubbed(:user)
        limiter = described_class.limiter_for(:users_get_by_id)

        limiter.check({ user: user.id }) # real traffic, count now 1

        result = limiter.peek({ user: user.id, bypass_header: '1' })

        expect(result.skipped?).to be(true)
        expect(result.rule.name).to eq('users_get_by_id_bypass')

        count = Gitlab::Redis::RateLimiting.with do |r|
          r.get("labkit:rl:{applimiter_users_get_by_id:limit_user_lookups_by_user:user:#{user.id}}")
        end
        expect(count.to_i).to eq(1) # unchanged by the bypassed peek
      end

      it 'names the bypass rule per key so bypass volume is distinguishable per limit' do
        expect(described_class.limiter_for(:pipelines_create).check(
          { project: 1, user: 1, sha: 'a', bypass_header: '1' }
        ).rule.name).to eq('pipelines_create_bypass')
      end
    end
  end

  describe '.accepts_context?' do
    it 'returns false for fixed values' do
      expect(described_class.accepts_context?(1)).to be(false)
    end

    it 'returns false for zero-arity callables' do
      expect(described_class.accepts_context?(-> { 1 })).to be(false)
    end

    it 'returns true for one-arity callables' do
      expect(described_class.accepts_context?(->(_ctx) { 1 })).to be(true)
    end

    it 'returns false for variadic callables' do
      expect(described_class.accepts_context?(->(*_ctx) { 1 })).to be(false)
    end
  end

  describe '.limit_for' do
    let(:rule) do
      ::Labkit::RateLimit::Rule.new(
        name: 'limit_configured_limit',
        characteristics: %i[user],
        limit: ->(ctx) { ctx&.dig(:threshold) || 3 },
        period: ->(ctx) { ctx&.dig(:interval) || 1.minute },
        action: :limit
      )
    end

    before do
      allow(described_class).to receive(:rule_for).with(:configured_limit).and_return(rule)
    end

    it 'resolves registry callables' do
      expect(described_class.limit_for(:configured_limit)).to eq(3)
    end

    it 'prefers caller context overrides' do
      expect(described_class.limit_for(:configured_limit, context: { threshold: 5 })).to eq(5)
    end

    it 'preserves zero caller overrides' do
      expect(described_class.limit_for(:configured_limit, context: { threshold: 0 })).to eq(0)
    end
  end

  describe ':project_value_stream_analytics' do
    let(:project) { build_stubbed(:project) }
    let(:other_project) { build_stubbed(:project) }

    it 'is a staged key with the threshold', :aggregate_failures do
      expect(described_class.staged?(:project_value_stream_analytics)).to be(true)
      expect(described_class.limit_for(:project_value_stream_analytics)).to eq(60)
    end

    it 'is enforced for projects with the flag enabled', :aggregate_failures do
      stub_feature_flags(project_value_stream_analytics_rate_limit: project)

      expect(described_class.enforced?(:project_value_stream_analytics, { project: project })).to be(true)
      expect(described_class.enforced?(:project_value_stream_analytics, { project: other_project })).to be(false)
    end

    context 'when the project_value_stream_analytics_rate_limit feature flag is disabled' do
      before do
        stub_feature_flags(project_value_stream_analytics_rate_limit: false)
      end

      it 'is not enforced' do
        expect(described_class.enforced?(:project_value_stream_analytics, { project: project })).to be(false)
      end
    end
  end

  describe ':value_stream_stage_metrics' do
    let(:user) { build_stubbed(:user) }
    let(:other_user) { build_stubbed(:user) }

    it 'is a staged key with the threshold', :aggregate_failures do
      expect(described_class.staged?(:value_stream_stage_metrics)).to be(true)
      expect(described_class.limit_for(:value_stream_stage_metrics)).to eq(150)
    end

    it 'is enforced for users with the flag enabled', :aggregate_failures do
      stub_feature_flags(vsa_stage_metrics_rate_limit: user)

      expect(described_class.enforced?(:value_stream_stage_metrics, { user: user })).to be(true)
      expect(described_class.enforced?(:value_stream_stage_metrics, { user: other_user })).to be(false)
      expect(described_class.enforced?(:value_stream_stage_metrics, { ip: '1.2.3.4' })).to be(false)
    end

    it 'is enforced for anonymous callers when the flag is enabled for everyone' do
      stub_feature_flags(vsa_stage_metrics_rate_limit: true)

      expect(described_class.enforced?(:value_stream_stage_metrics, { ip: '1.2.3.4' })).to be(true)
    end

    context 'when the vsa_stage_metrics_rate_limit feature flag is disabled' do
      before do
        stub_feature_flags(vsa_stage_metrics_rate_limit: false)
      end

      it 'is not enforced' do
        expect(described_class.enforced?(:value_stream_stage_metrics, { user: user })).to be(false)
      end
    end
  end

  describe '.limit_for the caller-threshold rules' do
    %i[
      emails_on_push_outbound_emails_per_hour
      emails_on_push_outbound_emails_per_day
      pipelines_email_outbound_emails_per_hour
      pipelines_email_outbound_emails_per_day
      organization_web_hook_calls
      integration_executions
      integration_executions_datadog
      service_desk_external_participants_per_day
    ].each do |key|
      it "resolves #{key} from the caller threshold, defaulting to 0", :aggregate_failures do
        expect(described_class.limit_for(key, context: { threshold: 7 })).to eq(7)
        expect(described_class.limit_for(key)).to eq(0)
      end
    end
  end

  describe 'the Service Desk external participants rule' do
    subject(:rule) { described_class.rule_for(:service_desk_external_participants_per_day) }

    it 'counts distinct email digests and admits emails already counted', :aggregate_failures do
      expect(rule.count_distinct).to eq(:email_digest)
      expect(rule.admit_counted_values).to be(true)
    end
  end

  describe '.limit_for the pages deployments rules' do
    before do
      stub_application_setting(pages_deployments_api_limit: 7)
    end

    %i[pages_deployments_api pages_deployments_api_unauthenticated].each do |key|
      it "resolves #{key} from the application setting whatever the flag state", :aggregate_failures do
        expect(described_class.limit_for(key)).to eq(7)

        stub_feature_flags(pages_deployments_api_rate_limit: false)

        expect(described_class.limit_for(key)).to eq(7)
      end

      it "stages #{key}" do
        expect(described_class.staged?(key)).to be(true)
      end
    end
  end

  describe '.enforced? for the pages deployments rules' do
    let_it_be(:user) { create(:user) }
    let_it_be(:other_user) { create(:user) }

    it 'enforces pages_deployments_api when the flag is enabled for the user', :aggregate_failures do
      stub_feature_flags(pages_deployments_api_rate_limit: user)

      expect(described_class.enforced?(:pages_deployments_api, { user: user })).to be(true)
      expect(described_class.enforced?(:pages_deployments_api, { user: other_user })).to be(false)
    end

    it 'does not enforce pages_deployments_api when the flag is disabled' do
      stub_feature_flags(pages_deployments_api_rate_limit: false)

      expect(described_class.enforced?(:pages_deployments_api, { user: user })).to be(false)
    end

    it 'enforces pages_deployments_api_unauthenticated when the flag is enabled', :aggregate_failures do
      expect(described_class.enforced?(:pages_deployments_api_unauthenticated, { ip: '127.0.0.1' })).to be(true)

      stub_feature_flags(pages_deployments_api_rate_limit: false)

      expect(described_class.enforced?(:pages_deployments_api_unauthenticated, { ip: '127.0.0.1' })).to be(false)
    end
  end

  describe 'the metric_definitions_download rule' do
    let(:key) { :metric_definitions_download }

    it 'allows 30 requests per minute', :aggregate_failures do
      expect(described_class.limit_for(key)).to eq(30)
      expect(described_class.period_for(key)).to eq(1.minute)
    end

    it 'counts requests per IP address' do
      expect(described_class.rule_for(key).characteristics).to eq(%i[ip])
    end

    it 'is staged and enforced only when rate_limit_metric_definitions is enabled', :aggregate_failures do
      expect(described_class.staged?(key)).to be(true)
      expect(described_class.enforced?(key, { ip: '127.0.0.1' })).to be(true)

      stub_feature_flags(rate_limit_metric_definitions: false)

      expect(described_class.enforced?(key, { ip: '127.0.0.1' })).to be(false)
    end
  end

  describe 'the merge_request_diff_download rule' do
    let(:key) { :merge_request_diff_download }
    let(:user) { build_stubbed(:user) }
    let(:other_user) { build_stubbed(:user) }
    let(:ip_scope) { { ip: '127.0.0.1' } }

    before do
      stub_application_setting(merge_request_diff_download_request_limit: 7)
    end

    it 'resolves the limit from the application setting whatever the flag state', :aggregate_failures do
      expect(described_class.limit_for(key)).to eq(7)

      stub_feature_flags(merge_request_diff_download_rate_limit: false)

      expect(described_class.limit_for(key)).to eq(7)
    end

    it 'is a staged key keyed by user or IP', :aggregate_failures do
      expect(described_class.staged?(key)).to be(true)
      expect(described_class.rule_for(key).characteristics).to eq(%i[user ip])
    end

    it 'is enforced for a signed-in user the flag is enabled for', :aggregate_failures do
      stub_feature_flags(merge_request_diff_download_rate_limit: user)

      expect(described_class.enforced?(key, { user: user })).to be(true)
      expect(described_class.enforced?(key, { user: other_user })).to be(false)
      expect(described_class.enforced?(key, ip_scope)).to be(false)
    end

    it 'is enforced for an IP address when the flag is enabled for the instance' do
      stub_feature_flags(merge_request_diff_download_rate_limit: true)

      expect(described_class.enforced?(key, ip_scope)).to be(true)
    end

    context 'when the merge_request_diff_download_rate_limit feature flag is disabled' do
      before do
        stub_feature_flags(merge_request_diff_download_rate_limit: false)
      end

      it 'is not enforced', :aggregate_failures do
        expect(described_class.enforced?(key, { user: user })).to be(false)
        expect(described_class.enforced?(key, ip_scope)).to be(false)
      end
    end
  end

  describe 'the merge_request_diffs_page rule' do
    let(:key) { :merge_request_diffs_page }
    let(:user) { build_stubbed(:user) }
    let(:other_user) { build_stubbed(:user) }
    let(:ip_scope) { { ip: '127.0.0.1' } }

    it 'is a staged key keyed by user or IP', :aggregate_failures do
      expect(described_class.staged?(key)).to be(true)
      expect(described_class.rule_for(key).characteristics).to eq(%i[user ip])
    end

    it 'resolves the limit from the application setting whatever the flag state', :aggregate_failures do
      stub_application_setting(merge_request_diffs_page_request_limit: 7)

      expect(described_class.limit_for(key)).to eq(7)

      stub_feature_flags(merge_request_diffs_page_rate_limit: false)

      expect(described_class.limit_for(key)).to eq(7)
    end

    it 'is enforced for a signed-in user the flag is enabled for', :aggregate_failures do
      stub_feature_flags(merge_request_diffs_page_rate_limit: user)

      expect(described_class.enforced?(key, { user: user })).to be(true)
      expect(described_class.enforced?(key, { user: other_user })).to be(false)
      expect(described_class.enforced?(key, ip_scope)).to be(false)
    end

    it 'is enforced for an IP address when the flag is enabled for the instance' do
      expect(described_class.enforced?(key, ip_scope)).to be(true)
    end

    it 'is not enforced when the flag is disabled', :aggregate_failures do
      stub_feature_flags(merge_request_diffs_page_rate_limit: false)

      expect(described_class.enforced?(key, { user: user })).to be(false)
      expect(described_class.enforced?(key, ip_scope)).to be(false)
    end
  end

  describe 'the graphql_participant_fields rule' do
    let(:key) { :graphql_participant_fields }
    let(:user) { build_stubbed(:user) }
    let(:other_user) { build_stubbed(:user) }
    let(:ip_scope) { { ip: '127.0.0.1' } }

    it 'is a staged key keyed by user or IP', :aggregate_failures do
      expect(described_class.staged?(key)).to be(true)
      expect(described_class.rule_for(key).characteristics).to eq(%i[user ip])
    end

    it 'resolves the limit from the application setting whatever the flag state', :aggregate_failures do
      stub_application_setting(graphql_participant_fields_request_limit: 7)

      expect(described_class.limit_for(key)).to eq(7)

      stub_feature_flags(graphql_participant_fields_rate_limit: false)

      expect(described_class.limit_for(key)).to eq(7)
    end

    it 'is enforced for a signed-in user the flag is enabled for', :aggregate_failures do
      stub_feature_flags(graphql_participant_fields_rate_limit: user)

      expect(described_class.enforced?(key, { user: user })).to be(true)
      expect(described_class.enforced?(key, { user: other_user })).to be(false)
      expect(described_class.enforced?(key, ip_scope)).to be(false)
    end

    it 'is enforced for an IP address when the flag is enabled for the instance' do
      expect(described_class.enforced?(key, ip_scope)).to be(true)
    end

    it 'is not enforced when the flag is disabled', :aggregate_failures do
      stub_feature_flags(graphql_participant_fields_rate_limit: false)

      expect(described_class.enforced?(key, { user: user })).to be(false)
      expect(described_class.enforced?(key, ip_scope)).to be(false)
    end
  end

  describe 'the merge_request_diff_resources rule' do
    let(:key) { :merge_request_diff_resources }
    let(:user) { build_stubbed(:user) }
    let(:other_user) { build_stubbed(:user) }
    let(:ip_scope) { { ip: '127.0.0.1' } }

    it 'is a staged key keyed by user or IP', :aggregate_failures do
      expect(described_class.staged?(key)).to be(true)
      expect(described_class.rule_for(key).characteristics).to eq(%i[user ip])
    end

    it 'resolves the limit from the application setting whatever the flag state', :aggregate_failures do
      stub_application_setting(merge_request_diff_resources_request_limit: 7)

      expect(described_class.limit_for(key)).to eq(7)

      stub_feature_flags(merge_request_diff_resources_rate_limit: false)

      expect(described_class.limit_for(key)).to eq(7)
    end

    it 'is enforced for a signed-in user the flag is enabled for', :aggregate_failures do
      stub_feature_flags(merge_request_diff_resources_rate_limit: user)

      expect(described_class.enforced?(key, { user: user })).to be(true)
      expect(described_class.enforced?(key, { user: other_user })).to be(false)
      expect(described_class.enforced?(key, ip_scope)).to be(false)
    end

    it 'is enforced for an IP address when the flag is enabled for the instance' do
      expect(described_class.enforced?(key, ip_scope)).to be(true)
    end

    it 'is not enforced when the flag is disabled', :aggregate_failures do
      stub_feature_flags(merge_request_diff_resources_rate_limit: false)

      expect(described_class.enforced?(key, { user: user })).to be(false)
      expect(described_class.enforced?(key, ip_scope)).to be(false)
    end
  end

  describe '.limit_for the delete_merged_branches rule' do
    before do
      stub_application_setting(delete_merged_branches_limit: 42)
    end

    it 'resolves the limit from the application setting whatever the flag state', :aggregate_failures do
      expect(described_class.limit_for(:delete_merged_branches)).to eq(42)

      stub_feature_flags(delete_merged_branches_rate_limit: false)

      expect(described_class.limit_for(:delete_merged_branches)).to eq(42)
    end

    it 'stages delete_merged_branches' do
      expect(described_class.staged?(:delete_merged_branches)).to be(true)
    end
  end

  describe '.limit_for the cross-project archive rules' do
    before do
      stub_application_setting(
        project_repositories_archive_limit: 42,
        project_repositories_archive_unauthenticated_limit: 21
      )
    end

    it 'resolves repositories_archive from the application setting whatever the flag state', :aggregate_failures do
      expect(described_class.limit_for(:repositories_archive)).to eq(42)

      stub_feature_flags(cross_project_archive_rate_limit: false)

      expect(described_class.limit_for(:repositories_archive)).to eq(42)
    end

    it 'resolves repositories_archive_unauthenticated from the application setting whatever the flag state',
      :aggregate_failures do
      expect(described_class.limit_for(:repositories_archive_unauthenticated)).to eq(21)

      stub_feature_flags(cross_project_archive_rate_limit: false)

      expect(described_class.limit_for(:repositories_archive_unauthenticated)).to eq(21)
    end

    %i[repositories_archive repositories_archive_unauthenticated].each do |key|
      it "stages #{key}" do
        expect(described_class.staged?(key)).to be(true)
      end
    end
  end

  describe '.enforced? for the cross-project archive rules' do
    let_it_be(:user) { create(:user) }
    let_it_be(:other_user) { create(:user) }

    it 'enforces repositories_archive when the flag is enabled for the user', :aggregate_failures do
      stub_feature_flags(cross_project_archive_rate_limit: user)

      expect(described_class.enforced?(:repositories_archive, { user: user })).to be(true)
      expect(described_class.enforced?(:repositories_archive, { user: other_user })).to be(false)
    end

    it 'does not enforce repositories_archive when the flag is disabled' do
      stub_feature_flags(cross_project_archive_rate_limit: false)

      expect(described_class.enforced?(:repositories_archive, { user: user })).to be(false)
    end

    it 'enforces repositories_archive_unauthenticated when the flag is enabled', :aggregate_failures do
      expect(described_class.enforced?(:repositories_archive_unauthenticated, { ip: '127.0.0.1' })).to be(true)

      stub_feature_flags(cross_project_archive_rate_limit: false)

      expect(described_class.enforced?(:repositories_archive_unauthenticated, { ip: '127.0.0.1' })).to be(false)
    end
  end

  describe 'project_export_by_root_namespace' do
    it 'keys on the namespace and reads the per-root-namespace setting', :aggregate_failures do
      stub_application_setting(project_export_limit_per_root_namespace: 3)

      expect(described_class.rule_for(:project_export_by_root_namespace).characteristics).to eq(%i[namespace])
      expect(described_class.limit_for(:project_export_by_root_namespace)).to eq(3)
      expect(described_class.period_for(:project_export_by_root_namespace)).to eq(10.minutes)
    end

    it 'defaults to no limit and is staged behind the flag', :aggregate_failures do
      expect(described_class.staged?(:project_export_by_root_namespace)).to be(true)
      expect(described_class.limit_for(:project_export_by_root_namespace)).to eq(0)
    end

    it 'enforces only while the flag is enabled' do
      stub_feature_flags(project_export_by_root_namespace_rate_limit: false)
      expect(described_class.enforced?(:project_export_by_root_namespace, { namespace: 1 })).to be(false)

      stub_feature_flags(project_export_by_root_namespace_rate_limit: true)
      expect(described_class.enforced?(:project_export_by_root_namespace, { namespace: 1 })).to be(true)
    end
  end

  describe '.period_for' do
    let(:configured_period_rule) do
      ::Labkit::RateLimit::Rule.new(
        name: 'limit_configured_period',
        characteristics: %i[user],
        limit: ->(ctx) { ctx&.dig(:threshold) || 1 },
        period: ->(ctx) { ctx&.dig(:interval) || 2.minutes },
        action: :limit
      )
    end

    let(:caller_period_rule) do
      ::Labkit::RateLimit::Rule.new(
        name: 'limit_caller_period',
        characteristics: %i[user],
        limit: ->(ctx) { ctx&.dig(:threshold) || 1 },
        period: ->(ctx) { ctx&.dig(:interval) || 0 },
        action: :limit
      )
    end

    before do
      allow(described_class).to receive(:rule_for).with(:configured_period).and_return(configured_period_rule)
      allow(described_class).to receive(:rule_for).with(:caller_period).and_return(caller_period_rule)
    end

    it 'resolves registry callables' do
      expect(described_class.period_for(:configured_period)).to eq(2.minutes)
    end

    it 'prefers caller context overrides' do
      expect(described_class.period_for(:configured_period, context: { interval: 5 })).to eq(5)
    end

    it 'preserves zero caller overrides' do
      expect(described_class.period_for(:configured_period, context: { interval: 0 })).to eq(0)
    end

    it 'resolves caller-supplied periods for entries without a registry period' do
      expect(described_class.period_for(:caller_period, context: { interval: 10 })).to eq(10)
    end

    it 'falls back to zero for entries without a registry period or caller override' do
      expect(described_class.period_for(:caller_period)).to eq(0)
    end
  end

  describe 'pipeline trigger token management rule' do
    it 'reads the per-user limit from the application settings' do
      stub_application_setting(pipeline_trigger_management_limit_per_user: 7)

      expect(described_class.rule_for(:pipeline_trigger_management).limit.call).to eq(7)
    end
  end
end
