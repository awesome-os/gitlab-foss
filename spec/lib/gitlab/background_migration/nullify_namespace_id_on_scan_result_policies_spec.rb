# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::BackgroundMigration::NullifyNamespaceIdOnScanResultPolicies,
  feature_category: :security_policy_management do
  let(:organizations) { table(:organizations) }
  let(:namespaces) { table(:namespaces) }
  let(:projects) { table(:projects) }
  let(:policy_configurations) { table(:security_orchestration_policy_configurations) }
  let(:scan_result_policies) { table(:scan_result_policies) }

  let(:organization) { organizations.create!(name: 'organization', path: 'organization') }
  let(:group) { namespaces.create!(name: 'group', path: 'group', type: 'Group', organization_id: organization.id) }

  let(:project) do
    projects.create!(name: 'project', path: 'project', organization_id: organization.id,
      project_namespace_id: group.id, namespace_id: group.id)
  end

  let(:policy_configuration) do
    policy_configurations.create!(namespace_id: group.id, security_policy_management_project_id: project.id)
  end

  let(:migration_args) do
    {
      start_cursor: [0],
      end_cursor: [scan_result_policies.maximum(:id)],
      batch_table: :scan_result_policies,
      batch_column: :id,
      sub_batch_size: 2,
      pause_ms: 0,
      connection: ApplicationRecord.connection
    }
  end

  let!(:rows) do
    # trigger_b83b7e51e2f5 clears namespace_id when project_id is set, so it is disabled to seed the legacy rows.
    ApplicationRecord.connection.execute('ALTER TABLE scan_result_policies DISABLE TRIGGER trigger_b83b7e51e2f5')

    {
      both: Array.new(3) { |i| create_read(rule_idx: i, namespace_id: group.id, project_id: project.id) },
      namespace_only: create_read(rule_idx: 3, namespace_id: group.id),
      project_only: create_read(rule_idx: 4, project_id: project.id)
    }
  ensure
    ApplicationRecord.connection.execute('ALTER TABLE scan_result_policies ENABLE TRIGGER trigger_b83b7e51e2f5')
  end

  describe '#perform' do
    subject(:perform_migration) { described_class.new(**migration_args).perform }

    it 'nullifies namespace_id on rows where project_id is also set' do
      perform_migration

      rows[:both].each do |row|
        expect(scan_result_policies.find(row.id)).to have_attributes(namespace_id: nil, project_id: project.id)
      end
    end

    it 'does not modify namespace_id-only rows' do
      expect { perform_migration }.not_to change { scan_result_policies.find(rows[:namespace_only].id).attributes }

      expect(scan_result_policies.find(rows[:namespace_only].id))
        .to have_attributes(namespace_id: group.id, project_id: nil)
    end

    it 'does not modify project_id-only rows' do
      expect { perform_migration }.not_to change { scan_result_policies.find(rows[:project_only].id).attributes }

      expect(scan_result_policies.find(rows[:project_only].id))
        .to have_attributes(namespace_id: nil, project_id: project.id)
    end

    it 'is idempotent' do
      2.times { perform_migration }

      expect(scan_result_policies.where.not(namespace_id: nil).where.not(project_id: nil)).to be_empty
    end

    it 'only updates rows within the job range' do
      outside_row = rows[:both].last

      described_class.new(**migration_args.merge(end_cursor: [rows[:both].second.id])).perform

      expect(scan_result_policies.find(outside_row.id).namespace_id).to eq(group.id)
    end

    context 'when there are no rows' do
      before do
        scan_result_policies.delete_all
      end

      it 'does not raise an error' do
        expect { described_class.new(**migration_args.merge(end_cursor: [0])).perform }.not_to raise_error
      end
    end
  end

  def create_read(rule_idx:, **attributes)
    scan_result_policies.create!(
      security_orchestration_policy_configuration_id: policy_configuration.id,
      orchestration_policy_idx: 0,
      rule_idx: rule_idx,
      **attributes
    )
  end
end
