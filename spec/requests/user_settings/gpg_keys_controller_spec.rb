# frozen_string_literal: true

require 'spec_helper'

RSpec.describe UserSettings::GpgKeysController, feature_category: :user_profile do
  let(:user) { create(:user, :with_namespace, email: GpgHelpers::User1.emails[0]) }

  describe 'POST #create' do
    before do
      sign_in(user)
    end

    it 'creates a new key' do
      expect do
        post user_settings_gpg_keys_path, params: { gpg_key: build(:gpg_key).attributes }
      end.to change { GpgKey.count }.by(1)
    end

    context 'when the key is invalid' do
      it 'does not create a new key' do
        expect do
          post user_settings_gpg_keys_path, params: { gpg_key: build(:gpg_key, key: 'invalid').attributes }
        end.not_to change { GpgKey.count }
      end

      it 'does not run a subkeys query per existing key' do
        create(:gpg_key_with_subkeys, user: user)
        post_invalid_key # warm up sign-in tracking and other first-request queries

        control = ActiveRecord::QueryRecorder.new { post_invalid_key }

        create(:gpg_key, user: user, key: GpgHelpers::User3.public_key)
        create(:gpg_key, user: user, key: GpgHelpers::UserWithRevokedUid.public_key)

        expect { post_invalid_key }.not_to exceed_query_limit(control)
      end

      def post_invalid_key
        post user_settings_gpg_keys_path, params: { gpg_key: { key: 'invalid' } }
      end
    end

    context 'when the user already has the key' do
      let!(:gpg_key) { create(:gpg_key, user: user, key: GpgHelpers::User1.public_key) }

      def post_key(key)
        post user_settings_gpg_keys_path, params: { gpg_key: { key: key } }
      end

      it 'updates the stored key with the new version', :aggregate_failures do
        expect { post_key(GpgHelpers::User1.public_key_with_extra_signing_key) }
          .to change { gpg_key.subkeys.count }.by(1)
          .and not_change { GpgKey.count }

        expect(response).to redirect_to(user_settings_gpg_keys_path)
        expect(flash[:notice]).to eq(s_('Profiles|GPG key updated.'))
      end

      it 'answers that the key is up to date when the same key is added again', :aggregate_failures do
        expect { post_key(GpgHelpers::User1.public_key) }.not_to change { gpg_key.reload.updated_at }

        expect(response).to redirect_to(user_settings_gpg_keys_path)
        expect(flash[:notice]).to eq(s_('Profiles|This GPG key is already up to date.'))
      end

      it 'shows why the update was refused and keeps the stored key', :aggregate_failures do
        post_key(GpgHelpers::User1.revoked_public_key)

        expect(response).to have_gitlab_http_status(:ok)
        expect(response.body).to include(s_('Profiles|This GPG key is revoked. To stop GitLab from using it, ' \
          'select Revoke or Remove next to the key.'))
        expect(response.body).to include(help_page_path('user/project/repository/signed_commits/gpg.md',
          anchor: 'update-a-gpg-key'))
        expect(response.body).not_to include('Primary keyid')
        expect(gpg_key.reload.key).to eq(GpgHelpers::User1.public_key)
      end

      it 'shows the format error for a private key block without trying an update', :aggregate_failures do
        expect(Repositories::GpgKeys::UpdateService).not_to receive(:new)

        post_key(GpgHelpers::User1.secret_key)

        expect(response).to have_gitlab_http_status(:ok)
        expect(response.body).to include('A valid public GPG key begins with')
      end
    end

    context 'when another user has the key' do
      before do
        create(:gpg_key, key: GpgHelpers::User1.public_key)
      end

      it 'refuses the key as taken', :aggregate_failures do
        expect(Repositories::GpgKeys::UpdateService).not_to receive(:new)

        expect do
          post user_settings_gpg_keys_path,
            params: { gpg_key: { key: GpgHelpers::User1.public_key_with_extra_signing_key } }
        end.not_to change { GpgKey.count }

        expect(response).to have_gitlab_http_status(:ok)
        expect(response.body).to include('Fingerprint has already been taken')
      end
    end
  end
end
