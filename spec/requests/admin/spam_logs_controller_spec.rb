# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Admin::SpamLogsController, :enable_admin_mode, feature_category: :instance_resiliency do
  let(:admin) { create(:admin) }
  let(:user) { create(:user) }
  let!(:first_spam) { create(:spam_log, user: user) }
  let!(:second_spam) { create(:spam_log, user: user) }

  before do
    sign_in(admin)
  end

  describe 'GET /admin/spam_logs' do
    it 'lists spam logs' do
      get admin_spam_logs_path

      expect(response).to have_gitlab_http_status(:ok)
      expect(response.body).to include(first_spam.title, second_spam.title)
    end
  end

  describe 'DELETE /admin/spam_logs/:id' do
    it 'removes only the spam log when removing log' do
      expect { delete admin_spam_log_path(first_spam) }.to change { SpamLog.count }.by(-1)
      expect(User.find(user.id)).to be_truthy
      expect(response).to have_gitlab_http_status(:ok)
    end

    it 'initiates user removal', :sidekiq_inline do
      expect do
        delete admin_spam_log_path(first_spam, remove_user: true)
      end.not_to change { SpamLog.count }

      expect(response).to have_gitlab_http_status(:found)
      expect(Users::GhostUserMigration.where(user: user, initiator_user: admin)).to be_exists
      expect(flash[:notice]).to eq("User #{user.username} was successfully removed.")
    end
  end

  describe 'POST /admin/spam_logs/:id/mark_as_ham' do
    before do
      allow_next_instance_of(Spam::AkismetService) do |instance|
        allow(instance).to receive(:submit_ham).and_return(true)
      end
    end

    it 'submits the log as ham' do
      post mark_as_ham_admin_spam_log_path(first_spam)

      expect(response).to have_gitlab_http_status(:found)
      expect(SpamLog.find(first_spam.id).submitted_as_ham).to be_truthy
    end
  end
end
