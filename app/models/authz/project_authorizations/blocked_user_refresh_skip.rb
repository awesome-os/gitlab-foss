# frozen_string_literal: true

module Authz
  module ProjectAuthorizations
    # Decides whose project_authorizations refreshes are skipped because the user is blocked.
    #
    # Blocked humans cannot sign in or use tokens, so their rows are left as they are until the
    # user becomes active again, when the User state machine schedules a full refresh. Project bots
    # (user type project_bot, which group access tokens also use) are blocked when their last
    # access token is revoked, and are left as they are until deleted.
    class BlockedUserRefreshSkip
      BATCH_SIZE = 1_000

      class << self
        # Whether refreshes of the user's authorizations are skipped, and logs the refresh as skipped
        # when it is.
        #
        # @param user [User]
        # @param skipped_in [Symbol] the code path that skips it, one of :user_refresh,
        #   :project_recalculate, :safety_net_check or :verifier
        # @return [Boolean]
        def skip_and_log?(user, skipped_in:)
          return false unless applies_to?(user)

          log_skipped([user], skipped_in: skipped_in)

          true
        end

        # Returns the users whose rows a refresh leaves as they are, and logs them as skipped.
        #
        # @param user_ids [Array<Integer>]
        # @param skipped_in [Symbol] the code path that skips them, one of :user_refresh,
        #   :project_recalculate, :safety_net_check or :verifier
        # @return [Set<Integer>]
        def skipped_user_ids(user_ids, skipped_in:)
          # Checked before the lookup so that a disabled flag costs no query.
          enabled_user_ids = user_ids.uniq.select { |user_id| enabled_for?(::User.actor_from_id(user_id)) }

          skipped_users = enabled_user_ids.each_slice(BATCH_SIZE).flat_map do |batch|
            ::User.id_in(batch).where(user_type: skippable_user_types).with_states(*::User::BLOCKED_STATES)
              .select(:id, :user_type).preload(:custom_attributes)
              .reject { |user| deletion_started?(user) }
          end

          log_skipped(skipped_users, skipped_in: skipped_in) if skipped_users.any?

          skipped_users.to_set(&:id)
        end

        # Like {.skipped_user_ids}, for users that are already loaded: the state is read from them
        # and the deletion marks are looked up once for all of them.
        #
        # @param users [Array<User>]
        # @param skipped_in [Symbol] the code path that skips them, one of :user_refresh,
        #   :project_recalculate, :safety_net_check or :verifier
        # @return [Set<Integer>]
        def skipped_user_ids_among(users, skipped_in:)
          blocked_users = users.select { |user| skippable_blocked_user?(user) && enabled_for?(user) }

          skipped_and_logged(blocked_users, skipped_in: skipped_in)
        end

        # Reads the attributes in memory when the caller preloaded them, so a batch of users costs one query.
        def deletion_started?(user)
          if user.custom_attributes.loaded?
            user.custom_attributes.any? { |attribute| attribute.key == ::UserCustomAttribute::DELETION_STARTED_AT }
          else
            deletion_started_attributes.by_user_id(user.id).exists?
          end
        end

        private

        def applies_to?(user)
          skippable_blocked_user?(user) && enabled_for?(user) && !deletion_started?(user)
        end

        # Logs the users skipped by one refresh in a single line, so a caller that skips many users
        # at once does not write a line per user.
        def log_skipped(users, skipped_in:)
          Gitlab::AppJsonLogger.info(
            event: 'authorized_projects_refresh_skipped',
            'authorized_projects_refresh.skip_reason': 'user_blocked',
            'authorized_projects_refresh.skipped_in': skipped_in.to_s,
            'authorized_projects_refresh.skipped_users_count': users.size,
            'authorized_projects_refresh.skipped_humans_count': users.count(&:human?),
            'authorized_projects_refresh.skipped_project_bots_count': users.count(&:project_bot?)
          )
        end

        def skippable_blocked_user?(user)
          user.blocked? && skippable_user_type?(user)
        end

        def skippable_user_type?(user)
          user.human? || (user.project_bot? && skip_blocked_project_bots?)
        end

        def skippable_user_types
          skip_blocked_project_bots? ? %w[human project_bot] : %w[human]
        end

        # Checked for the instance, not per bot: the users lookup is built before it knows which
        # IDs are bots, and leaving bots out of it keeps the lookup off their rows.
        def skip_blocked_project_bots?
          Feature.enabled?(:skip_authorization_refresh_for_blocked_project_bots, :instance)
        end

        # Lookups for many users at once, such as ProjectTeam#max_member_access_for_user_ids, still read
        # project_authorizations, so a skipped row can grant access there after an unblock until the refresh runs.
        def enabled_for?(actor)
          Feature.enabled?(:skip_authorization_refresh_for_blocked_users, actor)
        end

        def skipped_and_logged(blocked_users, skipped_in:)
          skipped_users = blocked_users.each_slice(BATCH_SIZE).flat_map do |batch|
            deletion_started_ids = deletion_started_user_ids(batch.map(&:id)).to_set

            batch.reject { |user| deletion_started_ids.include?(user.id) }
          end

          log_skipped(skipped_users, skipped_in: skipped_in) if skipped_users.any?

          skipped_users.to_set(&:id)
        end

        def deletion_started_user_ids(user_ids)
          deletion_started_attributes.by_user_id(user_ids).pluck(:user_id) # rubocop: disable Database/AvoidUsingPluckWithoutLimit -- bounded by the batch
        end

        def deletion_started_attributes
          ::UserCustomAttribute.by_key(::UserCustomAttribute::DELETION_STARTED_AT)
        end
      end
    end
  end
end
