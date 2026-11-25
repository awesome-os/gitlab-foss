# frozen_string_literal: true

module Authz
  module ProjectAuthorizations
    # Checks a random sample of (user, project) pairs against UserProjectGrants, to find what the refresh events
    # missed. The stored rows, the calculation and the pending events are read in one snapshot. Every change writes
    # its event in its own transaction, and a chunk's rows commit before its events are processed, so a difference
    # with nothing pending that could fix it is drift. Drift queues a user_in_project event, which recalculates with
    # the same UserProjectGrants.
    class VerifyService
      include Gitlab::Loggable

      # Pairs from each side of the sample: stored rows and memberships.
      SAMPLE_SIZE = 50
      MAX_RUNTIME = 30.seconds
      OUTCOMES = %i[
        matches drift unconfirmed_drift calculations_disagree duplicate_rows suppressed deleted_project blocked_user
        failed
      ].freeze

      # @return [ServiceResponse] payload has :sampled, the number of pairs for each of OUTCOMES, and :complete,
      #   false when it ran out of time
      def execute
        counts = { sampled: 0, **OUTCOMES.index_with(0) }
        runtime_limiter = Gitlab::Metrics::RuntimeLimiter.new(MAX_RUNTIME)
        pairs = VerificationSample.new(SAMPLE_SIZE).pairs
        blocked = BlockedUserRefreshSkip.skipped_user_ids(pairs.map(&:first), skipped_in: :verifier)
        # Until memberships compute, dropped or handed-off events leave no queue row while their Sidekiq job
        # waits, so a difference can't be told from drift.
        confirming = RefreshEvent.computed?(:user_in_group)
        complete = true

        pairs.each do |user_id, project_id|
          if runtime_limiter.over_time?
            complete = false
            break
          end

          counts[:sampled] += 1
          counts[outcome(user_id, project_id, blocked, confirming)] += 1
        rescue StandardError => e
          # One bad pair mustn't lose the run's counts.
          Gitlab::ErrorTracking.track_exception(e, user_id: user_id, project_id: project_id)
          counts[:failed] += 1
        end

        counts.except(:sampled).each { |outcome, count| counter.increment({ outcome: outcome }, count) }
        ServiceResponse.success(payload: counts.merge(complete: complete))
      end

      private

      def outcome(user_id, project_id, blocked, confirming)
        # Blocked users keep their rows until they are active again, so their difference isn't drift.
        return :blocked_user if blocked.include?(user_id)

        result = verify(user_id, project_id, confirming)
        return result unless result.is_a?(Hash)

        cause = if !confirming then :unconfirmed_drift
                elsif result[:project_level] == result[:expected_level] then :drift
                else :calculations_disagree
                end

        log_drift(user_id, project_id, cause, result)
        # When project refreshes calculate something else, a repair would be undone by the next one, so only
        # a difference both calculations agree on is repaired.
        RefreshEvent.enqueue(:user_in_project, [[user_id, project_id]]) if cause == :drift
        cause
      end

      # @return [Symbol, Hash] the outcome, or the levels found for a difference nothing pending explains
      def verify(user_id, project_id, confirming)
        in_one_snapshot do
          ::ApplicationRecord.uncached do
            project = ::Project.find_by_id(project_id)
            # Rows of deleted projects wait for loose foreign key cleanup, and rightly grant nothing.
            next :deleted_project if project.nil? || project.pending_delete?

            stored = ::ProjectAuthorization.stored_levels_for_user(user_id, [project_id]).fetch(project_id, [])
            level = UserProjectGrants.new(user_id, cached: false).max_access_levels([project_id])[project_id]
            next :matches if WriteBatchService.unchanged?(stored, level)
            # Legacy duplicate rows whose highest level is right change nobody's access; a refresh rewrites them.
            next :duplicate_rows if stored.size > 1 && stored.max == level.to_i
            next :suppressed if pending?(user_id, project)

            levels = { stored_level: stored.max.to_i, expected_level: level.to_i }
            confirming ? levels.merge(project_level: project_level(project, user_id)) : levels
          end
        end
      end

      def pending?(user_id, project)
        RefreshEvent.expansion_pending? ||
          RefreshEvent.pending_for?(user_id: user_id, project_id: project.id,
            namespace_ids: project.namespace.traversal_ids)
      end

      # @note What a project refresh would write: run only for a difference, since it costs tens of queries.
      def project_level(project, user_id)
        Projects::Members::EffectiveAccessLevelPerUserFinder.new(project, [user_id]).execute.to_h[user_id].to_i
      end

      # @note A transaction the caller already opened reads one snapshot per statement, and its isolation level
      #   can't be changed. The cron worker never has one.
      def in_one_snapshot(&)
        connection = ::ProjectAuthorization.connection
        return connection.transaction(&) if connection.transaction_open?

        connection.transaction(isolation: :repeatable_read, &)
      end

      def log_drift(user_id, project_id, cause, levels)
        Gitlab::AppJsonLogger.info(build_structured_payload_labkit(
          Labkit::Fields::LOG_MESSAGE => 'Project authorization drift found',
          Labkit::Fields::GL_USER_ID => user_id,
          Labkit::Fields::GL_PROJECT_ID => project_id,
          cause: cause.to_s,
          **levels
        ))
      end

      def counter
        @counter ||= Gitlab::Metrics.counter(:gitlab_authz_refresh_verifier_pairs_total,
          'Pairs of user and project checked by the project_authorizations verifier, by outcome')
      end
    end
  end
end
