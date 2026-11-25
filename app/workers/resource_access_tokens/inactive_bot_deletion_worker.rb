# frozen_string_literal: true

module ResourceAccessTokens
  # Runs up to InactiveTokensDeletionCronWorker::DELETION_SPREAD after the bot was found inactive,
  # so it checks again in case a token was rotated or created in the meantime.
  class InactiveBotDeletionWorker
    include ApplicationWorker

    idempotent!
    data_consistency :sticky
    feature_category :system_access

    def perform(user_id)
      cut_off = InactiveTokensDeletionCronWorker.cut_off
      return unless cut_off

      user = InactiveTokensDeletionCronWorker.inactive_bots(User.project_bot.id_in(user_id), cut_off).first
      return unless user

      admin_bot = Users::Internal.in_organization(user.organization_id).admin_bot

      DeleteUserWorker.perform_async(
        admin_bot.id,
        user.id,
        { 'skip_authorization' => true, 'reason_for_deletion' => 'No active token assigned' }
      )
    end
  end
end
