# frozen_string_literal: true

module Authz
  module ProjectAuthorizations
    # Recalculates one project's project_authorizations for every user: an unlocked comparison to find the
    # users whose rows are wrong, then a WriteBatchService write for those users, one chunk at a time.
    class RecalculateProjectService
      # WriteBatchService calculates and writes this many users per transaction.
      CHUNK_SIZE = WriteBatchService::BATCH_SIZE

      # @param project_id [Integer]
      # @param runtime_limiter [Gitlab::Metrics::RuntimeLimiter, nil] stops between chunks once over its limit
      def initialize(project_id, runtime_limiter: nil)
        @project_id = project_id
        @runtime_limiter = runtime_limiter
      end

      # @return [ServiceResponse] payload has :complete, false when the limiter stopped it early, :requested, the
      #   WriteBatchService::Result the comparison found, and :written, the one this run wrote
      def execute
        written = WriteBatchService::Result.new(0, 0)
        project, fresh, stored_user_ids = WriteBatchService.read_together do
          found = find_project
          [found, fresh_levels(found), read_stored_user_ids] if found
        end
        return response(true, written, written) unless project

        changed, requested = changed_users(fresh, stored_user_ids)
        stopped = false

        changed.each_slice(CHUNK_SIZE).with_index do |chunk, index|
          if index > 0 && runtime_limiter&.over_time?
            stopped = true
            break
          end

          written += WriteBatchService.new(project_id: project_id).execute(chunk) do |ids|
            # Load the project again: the finder reads its namespace and share lock from memory, and the
            # project may have moved since the comparison.
            fresh_project = find_project
            fresh_project ? per_user_levels(fresh_project, ids) : {}
          end
        end

        response(!stopped, requested, written)
      end

      private

      attr_reader :project_id, :runtime_limiter

      def find_project
        ::Project.find_by_id(project_id)
      end

      # @return [Hash{Integer => Integer}] each user's calculated access level
      def fresh_levels(project)
        ::ApplicationRecord.uncached { Projects::Members::EffectiveAccessLevelFinder.new(project).execute.to_h }
      end

      # From the primary: replicas can't skip dead index entries, so a read soon after a large removal can time
      # out there.
      #
      # @return [Array<Integer>] the users with stored rows for the project
      def read_stored_user_ids
        session = ::Gitlab::Database::LoadBalancing::SessionMap.current(::ProjectAuthorization.load_balancer)
        session.use_primary do
          ::ApplicationRecord.uncached { ::ProjectAuthorization.stored_levels_for_project(project_id).keys }
        end
      end

      # Users whose rows don't match the calculation, including users who lost all access. The stored rows are
      # read again under wait_for_project_writers' locks, so a write in progress can't make a pair look unchanged.
      # @return [Array(Array<Integer>, WriteBatchService::Result)] the users, and the rows writing them would
      #   add and delete
      def changed_users(fresh, stored_user_ids)
        stored = WriteBatchService.wait_for_project_writers(project_id, fresh.keys | stored_user_ids) do
          ::ApplicationRecord.uncached { ::ProjectAuthorization.stored_levels_for_project(project_id) }
        end

        changed = (fresh.keys | stored.keys).reject do |user_id|
          WriteBatchService.unchanged?(stored.fetch(user_id, []), fresh[user_id])
        end

        # Blocked users keep their rows until they are active again.
        skipped = WriteBatchService.read_together do
          BlockedUserRefreshSkip.skipped_user_ids(changed, skipped_in: :project_recalculate)
        end
        changed = changed.reject { |user_id| skipped.include?(user_id) }

        requested = WriteBatchService::Result.new(
          changed.count { |user_id| fresh[user_id] },
          changed.sum { |user_id| stored.fetch(user_id, []).size }
        )

        [changed, requested]
      end

      def per_user_levels(project, user_ids)
        Projects::Members::EffectiveAccessLevelPerUserFinder.new(project, user_ids).execute.to_h
      end

      def response(complete, requested, written)
        ServiceResponse.success(payload: { complete: complete, requested: requested, written: written })
      end
    end
  end
end
