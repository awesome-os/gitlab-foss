# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ResourceAccessTokens::RevokeService, feature_category: :system_access do
  subject { described_class.new(user, resource, access_token).execute }

  let_it_be(:user) { create(:user) }
  let_it_be(:user_non_priviledged) { create(:user) }
  let_it_be(:resource_bot, reload: true) { create(:user, :project_bot) }

  let(:access_token) { create(:personal_access_token, user: resource_bot) }

  describe '#execute', :sidekiq_inline do
    shared_examples 'revokes access token' do
      it { expect(subject.success?).to be true }

      it { expect(subject.message).to eq("Access token #{access_token.name} has been revoked.") }

      it 'does not call the delete user worker' do
        expect(DeleteUserWorker).not_to receive(:perform_async)

        subject
      end

      it 'bot user retains membership' do
        subject

        expect(resource.reload).to have_user(resource_bot)
      end

      it 'logs the event' do
        allow(Gitlab::AppLogger).to receive(:info)

        subject

        expect(Gitlab::AppLogger).to have_received(:info).with("PROJECT ACCESS TOKEN REVOCATION: revoked_by: #{user.username}, project_id: #{resource.id}, token_user: #{resource_bot.name}, token_id: #{access_token.id}")
      end

      it 'blocks the bot user, which now has no active token' do
        subject

        expect(resource_bot.reload).to be_blocked
      end

      it 'logs the block' do
        allow(Gitlab::AppJsonLogger).to receive(:info).and_call_original

        subject

        expect(Gitlab::AppJsonLogger).to have_received(:info).with(
          event: 'project_bot_blocked_on_token_revocation',
          Labkit::Fields::GL_USER_ID => resource_bot.id,
          token_id: access_token.id,
          resource_type: resource.class.name.downcase,
          resource_id: resource.id,
          revoked_by_user_id: user.id,
          revoked_by_username: user.username
        )
      end

      context 'when the bot user has another active token' do
        before do
          create(:personal_access_token, user: resource_bot)
        end

        it 'does not block the bot user' do
          subject

          expect(resource_bot.reload).to be_active
        end
      end

      context 'when the bot user has only inactive tokens left' do
        before do
          create(:personal_access_token, :expired, user: resource_bot)
          create(:personal_access_token, :revoked, user: resource_bot)
        end

        it 'blocks the bot user' do
          subject

          expect(resource_bot.reload).to be_blocked
        end
      end

      context 'when the bot user is already blocked' do
        before do
          resource_bot.block!
        end

        it { expect(subject.success?).to be true }

        it 'does not log a block' do
          expect(Gitlab::AppJsonLogger).not_to receive(:info)
            .with(hash_including(event: 'project_bot_blocked_on_token_revocation'))

          subject
        end
      end

      context 'when the token belongs to a member who is not a bot' do
        let_it_be(:human_member) { create(:user, developer_of: resource) }

        let(:access_token) { create(:personal_access_token, user: human_member) }

        it 'does not block the member' do
          subject

          expect(human_member.reload).to be_active
        end
      end

      context 'when block_project_bots_on_last_token_revocation is disabled' do
        before do
          stub_feature_flags(block_project_bots_on_last_token_revocation: false)
        end

        it 'does not block the bot user' do
          subject

          expect(resource_bot.reload).to be_active
        end
      end
    end

    shared_examples 'rollback revoke steps' do
      it 'does not revoke the access token' do
        subject

        expect(access_token.reload.revoked?).to be false
      end

      it 'does not remove bot from member list' do
        subject

        expect(resource.reload).to have_user(resource_bot)
      end

      it 'does not transfer issuables of bot user to ghost user' do
        issue = create(:issue, author: resource_bot)

        subject

        expect(issue.reload.author.ghost?).to be false
      end

      it 'does not destroy project bot user' do
        subject

        expect(User.exists?(resource_bot.id)).to be_truthy
      end
    end

    shared_examples 'revoke fails' do |resource_type|
      let_it_be(:other_user) { create(:user) }

      context "when access token does not belong to this #{resource_type}" do
        it 'does not find the bot' do
          other_access_token = create(:personal_access_token, user: other_user)

          response = described_class.new(user, resource, other_access_token).execute

          expect(response.success?).to be false
          expect(response.message).to eq("Failed to find bot user")
          expect(access_token.reload.revoked?).to be false
        end
      end

      context 'when user does not have permission to destroy bot' do
        context "when non-#{resource_type} member tries to delete project bot" do
          it 'does not allow other user to delete bot' do
            response = described_class.new(other_user, resource, access_token).execute

            expect(response.success?).to be false
            expect(response.message).to eq("#{other_user.name} cannot delete #{access_token.user.name}")
            expect(access_token.reload.revoked?).to be false
          end
        end

        context "when non-priviledged #{resource_type} member tries to delete project bot" do
          it 'does not allow developer to delete bot' do
            response = described_class.new(user_non_priviledged, resource, access_token).execute

            expect(response.success?).to be false
            expect(response.message).to eq("#{user_non_priviledged.name} cannot delete #{access_token.user.name}")
            expect(access_token.reload.revoked?).to be false
          end
        end
      end

      context 'when deletion of bot user fails' do
        before do
          allow_next_instance_of(::ResourceAccessTokens::RevokeService) do |service|
            allow(service).to receive(:execute).and_return(false)
          end
        end

        it_behaves_like 'rollback revoke steps'
      end
    end

    context 'when resource is a project' do
      let_it_be(:resource) { create(:project, :private) }

      before_all do
        resource.add_maintainer(user)
        resource.add_developer(user_non_priviledged)
        resource.add_maintainer(resource_bot)
      end

      it_behaves_like 'revokes access token'

      it_behaves_like 'revoke fails', 'project'
    end

    context 'when resource is a group' do
      let_it_be(:resource) { create(:group, :private) }

      before_all do
        resource.add_owner(user)
        resource.add_maintainer(user_non_priviledged)
        resource.add_maintainer(resource_bot)
      end

      it_behaves_like 'revokes access token'

      it_behaves_like 'revoke fails', 'group'

      def project_created_after_revocation
        described_class.new(user, resource, access_token).execute

        create(:project, group: resource).tap do |project|
          AuthorizedProjectUpdate::ProjectRecalculateService.new(project).execute
        end
      end

      it 'leaves the blocked bot out of the authorizations of a project created afterwards' do
        project = project_created_after_revocation

        expect(project.project_authorizations.pluck(:user_id)).to contain_exactly(user.id, user_non_priviledged.id)
      end

      context 'when block_project_bots_on_last_token_revocation is disabled' do
        before do
          stub_feature_flags(block_project_bots_on_last_token_revocation: false)
        end

        it 'adds the bot to the authorizations of a project created afterwards' do
          expect(project_created_after_revocation.project_authorizations.pluck(:user_id))
            .to contain_exactly(user.id, user_non_priviledged.id, resource_bot.id)
        end
      end

      context 'when skip_authorization_refresh_for_blocked_project_bots is disabled' do
        before do
          stub_feature_flags(skip_authorization_refresh_for_blocked_project_bots: false)
        end

        it 'adds the blocked bot to the authorizations of a project created afterwards' do
          project = project_created_after_revocation

          expect(resource_bot.reload).to be_blocked
          expect(project.project_authorizations.pluck(:user_id))
            .to contain_exactly(user.id, user_non_priviledged.id, resource_bot.id)
        end
      end
    end
  end
end
