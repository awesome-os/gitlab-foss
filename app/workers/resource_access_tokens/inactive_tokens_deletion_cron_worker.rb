# frozen_string_literal: true

module ResourceAccessTokens
  class InactiveTokensDeletionCronWorker
    include ApplicationWorker
    include CronjobQueue
    include Gitlab::Utils::StrongMemoize

    idempotent!
    data_consistency :sticky
    feature_category :system_access

    BATCH_SIZE = 1000
    MAX_RUNTIME = 3.minutes
    # Token expiry is a date, so most bots become eligible at the same midnight. Spreading by user ID
    # keeps the deletions from landing at once. Kept well under a day so the next run doesn't requeue them.
    DELETION_SPREAD = 6.hours

    def self.cut_off
      Gitlab::CurrentSettings.inactive_resource_access_tokens_delete_after_days&.days&.ago
    end

    # rubocop:disable CodeReuse/ActiveRecord -- query is shared with InactiveBotDeletionWorker
    def self.inactive_bots(relation, cut_off)
      relation
        .select(:id, :username, :organization_id)
        .where(
          'NOT EXISTS (?)',
          PersonalAccessToken
            .select(1)
            .where('"personal_access_tokens"."user_id" = "users"."id"')
            .and(
              PersonalAccessToken.active
                .or(
                  PersonalAccessToken.expired_after(cut_off).or(PersonalAccessToken.revoked_after(cut_off))
                )
            )
        )
    end

    def perform(cursor = nil)
      cut_off = self.class.cut_off
      return unless cut_off

      runtime_limiter = Gitlab::Metrics::RuntimeLimiter.new(MAX_RUNTIME)

      User.project_bot.where('"users"."id" > ?', cursor || 0).each_batch(of: BATCH_SIZE) do |relation|
        initiate_deletion_for(self.class.inactive_bots(relation, cut_off))

        if runtime_limiter.over_time? # rubocop:disable Style/Next -- we must break iteration
          self.class.perform_in(2.minutes, relation.maximum(:id))

          break
        end
      end
    end
    # rubocop:enable CodeReuse/ActiveRecord

    private

    def initiate_deletion_for(users)
      users.each do |user|
        with_context(user: user) do
          InactiveBotDeletionWorker.perform_in(deletion_delay_for(user), user.id)
        end
      end
    end

    def deletion_delay_for(user)
      (user.id % DELETION_SPREAD.to_i).seconds
    end
  end
end
