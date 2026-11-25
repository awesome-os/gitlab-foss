# frozen_string_literal: true

require 'spec_helper'
require_migration!

RSpec.describe UpdateResolveDependencyBumpFoundationalFlowReference, feature_category: :dependency_management do
  let(:organizations) { table(:organizations) }
  let(:ai_catalog_items) { table(:ai_catalog_items) }

  let!(:organization) { organizations.create!(name: 'Test Org', path: 'test-org') }

  def create_item(reference)
    ai_catalog_items.create!(
      organization_id: organization.id,
      item_type: 2, # Ai::Catalog::Item::FLOW_TYPE
      name: "resolve-dependency-bump-#{reference.tr('/', '-')}",
      description: 'Resolve dependency bump breaking changes',
      foundational_flow_reference: reference
    )
  end

  context 'when the flow is registered under the experimental reference' do
    let!(:item) { create_item('resolve_dependency_bump/experimental') }

    it 'renames the reference in place, keeping the item id' do
      expect { migrate! }
        .to change { item.reload.foundational_flow_reference }
        .from('resolve_dependency_bump/experimental')
        .to('resolve_dependency_bump/v1')
    end

    it 'restores the experimental reference on rollback' do
      reversible_migration do |migration|
        migration.before -> {
          expect(item.reload.foundational_flow_reference).to eq('resolve_dependency_bump/experimental')
        }

        migration.after -> {
          expect(item.reload.foundational_flow_reference).to eq('resolve_dependency_bump/v1')
        }
      end
    end
  end

  context 'when the organization already has an item under the v1 reference' do
    let!(:experimental_item) { create_item('resolve_dependency_bump/experimental') }
    let!(:v1_item) { create_item('resolve_dependency_bump/v1') }

    it 'leaves the experimental item alone rather than creating a duplicate reference' do
      expect { migrate! }.not_to change { experimental_item.reload.foundational_flow_reference }
      expect(v1_item.reload.foundational_flow_reference).to eq('resolve_dependency_bump/v1')
    end
  end

  context 'with an item belonging to another organization' do
    let(:other_organization) { organizations.create!(name: 'Other Org', path: 'other-org') }

    let!(:other_item) do
      ai_catalog_items.create!(
        organization_id: other_organization.id,
        item_type: 2, # Ai::Catalog::Item::FLOW_TYPE
        name: 'other-org-resolve-dependency-bump',
        description: 'Resolve dependency bump breaking changes',
        foundational_flow_reference: 'resolve_dependency_bump/experimental'
      )
    end

    it 'renames it independently of the other organizations' do
      create_item('resolve_dependency_bump/v1')

      expect { migrate! }
        .to change { other_item.reload.foundational_flow_reference }
        .to('resolve_dependency_bump/v1')
    end
  end

  context 'with an unrelated foundational flow' do
    let!(:unrelated_item) { create_item('fix_pipeline/v1') }

    it 'does not touch it' do
      expect { migrate! }.not_to change { unrelated_item.reload.foundational_flow_reference }
    end
  end
end
