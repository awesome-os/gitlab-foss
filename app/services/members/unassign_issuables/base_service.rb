# frozen_string_literal: true

module Members
  module UnassignIssuables
    class BaseService
      attr_reader :user, :entity, :requesting_user

      # @param [User] user user whose membership is being deleted from entity
      # @param [Group, Project] entity
      # @param [User] requesting_user user who initiated the membership deletion of `user`
      def initialize(user, entity, requesting_user)
        @user = user
        @entity = entity
        @requesting_user = requesting_user
      end

      def execute
        raise ArgumentError, 'requesting_user must be given' unless requesting_user
        return ServiceResponse.success unless entity && user

        processed = 0
        skipped = 0
        still_assigned = 0
        batches = 0
        update_duration_s = 0.0
        start_time = monotonic_time

        assignees.each_batch(column: id_column) do |batch|
          batches += 1

          assignees_batch = batch.with_issuables_for_update.to_a
          preload_project_policies(assignees_batch)

          assignees_batch.each do |assignee|
            update_start_time = monotonic_time

            if unassign(issuable_for(assignee))
              processed += 1
            else
              skipped += 1
            end

            update_duration_s += monotonic_time - update_start_time
          end

          # An update can run and still leave the user assigned, for example without permission.
          still_assigned += batch.count
        end

        # Everything outside the update services: the batch lookups, loading each batch,
        # preloading its project policies and counting what is left.
        lookup_duration_s = (monotonic_time - start_time - update_duration_s).round(6)
        update_duration_s = update_duration_s.round(6)

        user.invalidate_cache_counts

        ServiceResponse.success(
          payload: payload(processed:, skipped:, still_assigned:, batches:, lookup_duration_s:, update_duration_s:)
        )
      end

      private

      # Loads the permission data that the update services check with `can?`, once per batch instead of per project.
      #
      # @param [Array<IssueAssignee, MergeRequestAssignee>] assignees_batch one batch, with issuables preloaded
      def preload_project_policies(assignees_batch)
        projects = assignees_batch.filter_map { |assignee| issuable_for(assignee)&.project }.uniq

        ::Preloaders::ProjectPolicyPreloader.new(projects, requesting_user).execute
      end

      # @return [Boolean] false when the issuable is gone, or was removed before the update saved
      def unassign(issuable)
        return false unless issuable

        save_assignees(issuable, remaining_assignee_ids(issuable))
        true
      rescue ActiveRecord::StaleObjectError
        # The issuable can be removed before the update service saves it. Continue with the next one.
        false
      end

      # Read right before the update, as a list preloaded with the batch could drop assignees added since.
      def remaining_assignee_ids(issuable)
        issuable.assignees.map(&:id) - [user.id]
      end

      def assignees
        assignee_class.for_assignee(user).in_projects(project_ids)
      end

      def project_ids
        @project_ids ||= entity.is_a?(Group) ? entity.all_projects.select(:id) : [entity.id]
      end

      def monotonic_time
        ::Gitlab::Metrics::System.monotonic_time
      end

      def assignee_class
        raise NotImplementedError
      end

      def id_column
        raise NotImplementedError
      end

      def payload(processed:, skipped:, still_assigned:, batches:, lookup_duration_s:, update_duration_s:)
        raise NotImplementedError
      end

      def issuable_for(_assignee)
        raise NotImplementedError
      end

      def save_assignees(_issuable, _assignee_ids)
        raise NotImplementedError
      end
    end
  end
end
