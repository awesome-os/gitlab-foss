# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Organizations::Isolation, feature_category: :organization do
  describe '.enabled?' do
    subject(:enabled?) { described_class.enabled? }

    let_it_be(:organization) { create(:organization) }

    context 'when data_isolation feature flag is disabled' do
      before do
        stub_feature_flags(data_isolation: false)
      end

      it { is_expected.to be false }
    end

    context 'when data_isolation feature flag is enabled' do
      before do
        stub_feature_flags(data_isolation: true)
      end

      context 'when Current.organization is not assigned' do
        it { is_expected.to be false }
      end

      context 'when Current.organization is assigned' do
        context 'when Current.organization is nil' do
          before do
            stub_current_organization(nil)
          end

          it { is_expected.to be false }
        end

        context 'when Current.organization is not isolated' do
          before do
            stub_current_organization(organization)
            allow(organization).to receive(:isolated?).and_return(false)
          end

          it { is_expected.to be false }
        end

        context 'when Current.organization is isolated' do
          before do
            stub_current_organization(organization)
            allow(organization).to receive(:isolated?).and_return(true)
          end

          it { is_expected.to be true }
        end

        it 'does not deadlock on recursive calls' do
          org = create(:organization)
          Current.organization = org

          expect { Project.find_by(id: 1) }.not_to raise_error
        end
      end
    end

    context 'when data isolation is disabled for the block' do
      before do
        stub_feature_flags(data_isolation: true)
        stub_current_organization(organization)
        allow(organization).to receive(:isolated?).and_return(true)
      end

      it 'is false inside the block and true again outside it' do
        Gitlab::Database::DataIsolation::ScopeHelper.without_data_isolation do
          expect(described_class.enabled?).to be false
        end

        expect(described_class.enabled?).to be true
      end

      it 'does not affect .enabled_ignoring_context?, which the Arel strategy calls there' do
        Gitlab::Database::DataIsolation::ScopeHelper.without_data_isolation do
          expect(described_class.enabled_ignoring_context?).to be true
        end
      end

      it 'wins over allow_query_scoping', :request_store do
        described_class.allow_query_scoping do
          Gitlab::Database::DataIsolation::ScopeHelper.without_data_isolation do
            expect(described_class.enabled?).to be false
          end
        end
      end
    end

    context 'when checking data_isolation feature flag raises an error' do
      before do
        allow(Feature).to receive(:enabled?).and_raise(Exception)
      end

      it { is_expected.to be false }
    end
  end

  describe '.allow_query_scoping', :request_store do
    let_it_be(:organization) { create(:organization) }

    before do
      stub_feature_flags(data_isolation: false)
      stub_current_organization(organization)
      allow(organization).to receive(:isolated?).and_return(true)
    end

    it 'ignores the disabled feature flag inside the block' do
      expect(described_class.enabled?).to be false

      described_class.allow_query_scoping do
        expect(described_class.enabled?).to be true
      end

      expect(described_class.enabled?).to be false
    end

    it 'still applies the other checks' do
      allow(organization).to receive(:isolated?).and_return(false)

      described_class.allow_query_scoping do
        expect(described_class.enabled?).to be false
      end
    end

    it 'restores the previous state when the block raises' do
      expect do
        described_class.allow_query_scoping { raise 'boom' }
      end.to raise_error('boom')

      expect(described_class.enabled?).to be false
    end

    it 'nests' do
      described_class.allow_query_scoping do
        described_class.allow_query_scoping do
          expect(described_class.enabled?).to be true
        end

        expect(described_class.enabled?).to be true
      end

      expect(described_class.enabled?).to be false
    end

    it 'returns the value of the block' do
      expect(described_class.allow_query_scoping { :result }).to be :result
    end

    context 'without an active request store' do
      before do
        RequestStore.end!
        RequestStore.clear!
      end

      it 'does not open one for the block', :aggregate_failures do
        described_class.allow_query_scoping do
          expect(described_class.enabled?).to be true
          expect(RequestStore).not_to be_active
        end
      end

      it 'leaves what is already in the request store' do
        RequestStore.store[:kept] = true

        described_class.allow_query_scoping { nil }

        expect(RequestStore.store[:kept]).to be true
      end
    end
  end

  describe '.organization_isolated?' do
    let_it_be(:isolated_organization) { create(:organization, :isolated) }
    let_it_be(:organization) { create(:organization) }

    it 'is true for an isolated organization' do
      expect(described_class.organization_isolated?(isolated_organization.id)).to be true
    end

    it 'is false for an organization that is not isolated' do
      expect(described_class.organization_isolated?(organization.id)).to be false
    end

    it 'is false without a query when there is no organization' do
      expect { expect(described_class.organization_isolated?(nil)).to be false }.not_to exceed_query_limit(0)
    end

    it 'is false when there is no organization and the current organization is assigned as nil' do
      stub_current_organization(nil)

      expect(described_class.organization_isolated?(nil)).to be false
    end

    it 'looks the isolation up once per request for an organization', :request_store do
      expect do
        2.times { described_class.organization_isolated?(isolated_organization.id) }
      end.not_to exceed_query_limit(1)
    end

    context 'when the organization is the current organization' do
      before do
        stub_current_organization(
          Organizations::Organization.find_by_id_with_isolation_record(isolated_organization.id)
        )
      end

      it 'reads the isolation from it without a query' do
        expect { expect(described_class.organization_isolated?(isolated_organization.id)).to be true }
          .not_to exceed_query_limit(0)
      end
    end

    context 'when the current organization is another one' do
      before do
        stub_current_organization(Organizations::Organization.find_by_id_with_isolation_record(organization.id))
      end

      it 'looks the isolation up' do
        expect { expect(described_class.organization_isolated?(isolated_organization.id)).to be true }
          .not_to exceed_query_limit(1)
      end
    end

    context 'when the current organization is another isolated one, with data isolation enabled' do
      let_it_be(:current_organization) { create(:organization, :isolated) }

      before do
        stub_feature_flags(data_isolation: true)
        stub_current_organization(Organizations::Organization.find_by_id_with_isolation_record(current_organization.id))
      end

      it 'answers for the organization asked about' do
        expect(described_class.organization_isolated?(isolated_organization.id)).to be true
      end
    end

    context 'when the current organization was assigned without its isolation record' do
      after do
        Current.reset
      end

      it 'does not deadlock with data isolation enabled' do
        stub_feature_flags(data_isolation: true)
        Current.organization = Organizations::Organization.find(isolated_organization.id)

        expect(described_class.organization_isolated?(isolated_organization.id)).to be true
      end

      it 'does not count as using the fallback organization', :request_store do
        Current.organization = Organizations::Organization.find(isolated_organization.id)
        Gitlab::Organizations::FallbackOrganizationTracker.enable

        described_class.organization_isolated?(isolated_organization.id)

        expect(Gitlab::Organizations::FallbackOrganizationTracker).to be_enabled
      end
    end
  end
end
