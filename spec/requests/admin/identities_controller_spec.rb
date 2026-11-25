# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Admin::IdentitiesController, :enable_admin_mode, feature_category: :system_access do
  let(:admin) { create(:admin) }

  before do
    sign_in(admin)
  end

  describe 'GET /admin/users/:user_id/identities' do
    context 'when the user has no identities' do
      it 'shows no identities' do
        get admin_user_identities_path(admin)

        expect(response).to have_gitlab_http_status(:ok)
        expect(response.body).to include('This user has no identities')
      end
    end

    context 'when the user has identities' do
      let(:ldap_user) { create(:omniauth_user, provider: 'ldapmain', extern_uid: 'ldap-uid') }

      it 'shows identities' do
        get admin_user_identities_path(ldap_user)

        expect(response).to have_gitlab_http_status(:ok)
        expect(response.body).to include('ldap-uid')
        expect(response.body).not_to include('This user has no identities')
      end
    end
  end

  describe 'PUT /admin/users/:user_id/identities/:id' do
    let(:user) { create(:omniauth_user, provider: 'ldapmain', extern_uid: 'uid=myuser,ou=people,dc=example,dc=com') }

    it 'repairs ldap blocks' do
      expect_next_instance_of(::Users::RepairLdapBlockedService) do |instance|
        expect(instance).to receive(:execute)
      end

      put admin_user_identity_path(user, user.ldap_identity), params: { identity: { provider: 'twitter' } }
    end
  end

  describe 'DELETE /admin/users/:user_id/identities/:id' do
    let(:user) { create(:omniauth_user, provider: 'ldapmain', extern_uid: 'uid=myuser,ou=people,dc=example,dc=com') }

    it 'repairs ldap blocks' do
      expect_next_instance_of(::Users::RepairLdapBlockedService) do |instance|
        expect(instance).to receive(:execute)
      end

      delete admin_user_identity_path(user, user.ldap_identity)
    end
  end
end
