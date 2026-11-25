# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Admin::KeysController, :enable_admin_mode, feature_category: :user_management do
  let_it_be(:admin) { create(:admin) }
  let_it_be(:user) { create(:user) }
  let_it_be(:key) { create(:key, user: user) }

  before do
    sign_in(admin)
  end

  describe 'GET /admin/users/:user_id/keys/:id' do
    it 'finds the key using permitted params' do
      get admin_user_key_path(user_id: user.username, id: key.id)

      expect(response).to have_gitlab_http_status(:ok)
    end

    it 'responds with JS format' do
      get admin_user_key_path(user_id: user.username, id: key.id, format: :js), xhr: true

      expect(response).to have_gitlab_http_status(:ok)
    end
  end

  describe 'DELETE /admin/users/:user_id/keys/:id' do
    it 'removes the key using permitted params' do
      expect do
        delete admin_user_key_path(user_id: user.username, id: key.id)
      end.to change { user.keys.count }.by(-1)

      expect(response).to redirect_to(keys_admin_user_path(user))
      expect(flash[:notice]).to eq('User key was successfully removed.')
    end

    context 'when key destruction fails' do
      before do
        allow_next_found_instance_of(Key) do |key_instance|
          allow(key_instance).to receive(:destroy).and_return(false)
        end
      end

      it 'shows an alert message' do
        delete admin_user_key_path(user_id: user.username, id: key.id)

        expect(response).to redirect_to(keys_admin_user_path(user))
        expect(flash[:alert]).to eq('Failed to remove user key.')
      end
    end
  end
end
