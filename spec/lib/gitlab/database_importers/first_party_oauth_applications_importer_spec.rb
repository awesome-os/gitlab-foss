# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::DatabaseImporters::FirstPartyOauthApplicationsImporter, feature_category: :system_access do
  let(:glab_uid) { '41d48f9422ebd655dd9cf2947d6979681dfaddc6d0c56f7628f6ada59559af1e' }
  let(:vscode_uid) { '36f2a70cddeb5a0889d4fd8295c241b7e9848e89cf9e599d0eed2d8e5350fbf5' }
  let(:jetbrains_uid) { '732efe7d78ba62b01d2a95cd3b02f3ca2a00c7cec32c01e060c1b7664a9aa367' }

  describe '.seed' do
    subject(:seed) { described_class.seed }

    context 'when the default organization exists' do
      # rubocop:disable Gitlab/AvoidConstDefaultOrganizationId -- the importer targets the default organization
      let_it_be(:organization) { create(:organization, id: Organizations::Organization::DEFAULT_ORGANIZATION_ID) }
      # rubocop:enable Gitlab/AvoidConstDefaultOrganizationId

      it 'creates the public, untrusted applications with the GitLab.com client IDs', :aggregate_failures do
        expect { seed }.to change { Authn::OauthApplication.count }.by(3)

        expect(Authn::OauthApplication.pluck(:uid)).to contain_exactly(glab_uid, vscode_uid, jetbrains_uid)

        glab = Authn::OauthApplication.find_by!(uid: glab_uid)

        expect(glab).to have_attributes(
          name: 'GitLab CLI', confidential: false, trusted: false, ropc_enabled: false, device_code_enabled: true,
          organization_id: organization.id, redirect_uri: 'http://localhost:7171/auth/redirect')
        expect(glab.scopes.to_s).to eq('openid profile read_user write_repository api')
      end

      it 'limits the editor integrations to the api scope' do
        seed

        expect(Authn::OauthApplication.where(uid: [vscode_uid, jetbrains_uid]).map { |app| app.scopes.to_s })
          .to all(eq('api'))
      end

      it 'registers the redirect URI of every VS Code variant' do
        seed

        expect(Authn::OauthApplication.find_by!(uid: vscode_uid).redirect_uri.split("\n")).to eq(%w[
          vscode://gitlab.gitlab-workflow/authentication
          vscode-insiders://gitlab.gitlab-workflow/authentication
          vscodium://gitlab.gitlab-workflow/authentication
        ])
      end

      it 'leaves an application that already exists untouched' do
        existing = create(:oauth_application, uid: glab_uid, name: 'Renamed by an admin', owner: nil,
          organization: organization)

        expect { seed }.to change { Authn::OauthApplication.count }.by(2)

        expect(existing.reload.name).to eq('Renamed by an admin')
      end

      it 'is idempotent' do
        seed

        expect { described_class.seed }.not_to change { Authn::OauthApplication.count }
      end
    end

    context 'when the default organization does not exist' do
      it 'creates nothing' do
        expect { seed }.not_to change { Authn::OauthApplication.count }
      end
    end
  end
end
