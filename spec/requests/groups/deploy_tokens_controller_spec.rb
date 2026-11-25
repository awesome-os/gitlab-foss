# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Groups::DeployTokensController, feature_category: :continuous_delivery do
  let_it_be(:user, freeze: false) { create(:user) }
  let_it_be(:group) { create(:group, owners: user) }
  let_it_be(:deploy_token) { create(:deploy_token, :group, groups: [group]) }
  let_it_be(:params) do
    { id: deploy_token.id, group_id: group }
  end

  before do
    sign_in(user)
  end

  describe 'PUT /groups/:group_path_with_namespace/-/deploy_tokens/:id/revoke' do
    subject(:put_revoke) do
      put "/groups/#{group.full_path}/-/deploy_tokens/#{deploy_token.id}/revoke", params: params
    end

    it 'invokes the Groups::DeployTokens::RevokeService' do
      expect(deploy_token.revoked).to be(false)
      expect(Groups::DeployTokens::RevokeService).to receive(:new).and_call_original

      put_revoke

      expect(deploy_token.reload.revoked).to be(true)
    end

    it 'redirects to group repository settings with correct anchor' do
      put_revoke

      expect(response).to have_gitlab_http_status(:redirect)
      expect(response).to redirect_to(group_settings_repository_path(group, anchor: 'js-deploy-tokens'))
    end

    context 'when the user cannot delete deploy tokens' do
      before do
        allow(Ability).to receive(:allowed?).and_call_original
        allow(Ability).to receive(:allowed?).with(user, :delete_deploy_token, group).and_return(false)
      end

      it 'responds with not found and does not revoke the token' do
        expect { put_revoke }.not_to change { deploy_token.reload.revoked }

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end
  end
end
