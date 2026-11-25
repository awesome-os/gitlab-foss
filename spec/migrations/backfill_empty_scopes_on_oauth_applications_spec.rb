# frozen_string_literal: true

require 'spec_helper'
require_migration!

RSpec.describe BackfillEmptyScopesOnOauthApplications, feature_category: :system_access do
  let(:organizations) { table(:organizations) }
  let(:oauth_applications) { table(:oauth_applications) }

  let!(:organization) { organizations.create!(name: 'Default', path: 'default') }
  let!(:app_without_scopes) { create_oauth_application(scopes: '') }
  let!(:app_with_scopes) { create_oauth_application(scopes: 'read_user') }
  let!(:app_at_max_id_without_scopes) { create_oauth_application(scopes: '', id: 175_000) }

  def create_oauth_application(scopes:, id: nil)
    oauth_applications.create!(
      id: id,
      name: "App #{SecureRandom.hex(4)}",
      uid: SecureRandom.hex(16),
      secret: SecureRandom.hex(32),
      redirect_uri: 'https://example.com/callback',
      scopes: scopes,
      organization_id: organization.id
    )
  end

  describe '#up' do
    context 'when on GitLab.com' do
      before do
        allow(Gitlab).to receive(:com_except_jh?).and_return(true)
      end

      it 'sets the configured scopes on applications without scopes' do
        migrate!

        expect(app_without_scopes.reload.scopes).to eq(described_class::SCOPES)
      end

      it 'does not change applications with scopes' do
        migrate!

        expect(app_with_scopes.reload.scopes).to eq('read_user')
      end

      it 'does not change applications at or above the maximum id' do
        migrate!

        expect(app_at_max_id_without_scopes.reload.scopes).to eq('')
      end
    end

    context 'when not on GitLab.com' do
      before do
        allow(Gitlab).to receive(:com_except_jh?).and_return(false)
      end

      it 'does not change applications' do
        migrate!

        expect(app_without_scopes.reload.scopes).to eq('')
      end
    end
  end

  describe '#down' do
    let!(:app_at_max_id_with_backfilled_list) do
      create_oauth_application(scopes: described_class::SCOPES, id: 175_001)
    end

    before do
      allow(Gitlab).to receive(:com_except_jh?).and_return(true)
    end

    it 'restores empty scopes only on backfilled applications' do
      reversible_migration do |migration|
        migration.before -> {
          expect(app_without_scopes.reload.scopes).to eq('')
          expect(app_with_scopes.reload.scopes).to eq('read_user')
          expect(app_at_max_id_with_backfilled_list.reload.scopes).to eq(described_class::SCOPES)
        }

        migration.after -> {
          expect(app_without_scopes.reload.scopes).to eq(described_class::SCOPES)
          expect(app_with_scopes.reload.scopes).to eq('read_user')
        }
      end
    end
  end
end
