# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ResourceAccessTokens::InactiveBotDeletionWorker, feature_category: :system_access do
  subject(:worker) { described_class.new }

  let(:cut_off_days) { 42 }
  let(:token) { create(:resource_access_token, expires_at: (cut_off_days + 1).days.ago) }
  let(:bot) { token.user }

  before do
    stub_application_setting(inactive_resource_access_tokens_delete_after_days: cut_off_days)
  end

  it_behaves_like 'an idempotent worker' do
    let(:job_args) { [bot.id] }
  end

  it_behaves_like 'worker with data consistency', described_class, data_consistency: :sticky

  describe '#perform' do
    it 'schedules deletion of a bot that is still inactive' do
      admin_bot = Users::Internal.in_organization(bot.organization).admin_bot

      expect(DeleteUserWorker).to receive(:perform_async).with(
        admin_bot.id,
        bot.id,
        { 'skip_authorization' => true, 'reason_for_deletion' => 'No active token assigned' }
      )

      worker.perform(bot.id)
    end

    it 'does not delete a bot that got an active token since it was scheduled' do
      create(:personal_access_token, user: bot)

      expect(DeleteUserWorker).not_to receive(:perform_async)

      worker.perform(bot.id)
    end

    it 'does not delete a user who is not a project bot' do
      user = create(:user)

      expect(DeleteUserWorker).not_to receive(:perform_async)

      worker.perform(user.id)
    end

    it 'does nothing when the setting is blank' do
      stub_application_setting(inactive_resource_access_tokens_delete_after_days: nil)

      expect(DeleteUserWorker).not_to receive(:perform_async)

      worker.perform(bot.id)
    end

    it 'does nothing when the user no longer exists' do
      expect(DeleteUserWorker).not_to receive(:perform_async)

      worker.perform(non_existing_record_id)
    end
  end
end
