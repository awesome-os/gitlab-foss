# frozen_string_literal: true

require 'spec_helper'
require_migration!

RSpec.describe RemoveDuplicateAnalyticsDevopsAdoptionSnapshots, feature_category: :devops_reports do
  let(:organizations) { table(:organizations) }
  let(:namespaces) { table(:namespaces) }
  let(:snapshots) { table(:analytics_devops_adoption_snapshots) }

  let(:organization) { organizations.create!(path: 'test-org') }
  let(:group) { namespaces.create!(name: 'group', path: 'group', type: 'Group', organization_id: organization.id) }
  let(:other_group) do
    namespaces.create!(name: 'other', path: 'other', type: 'Group', organization_id: organization.id)
  end

  let(:month_end) { Time.utc(2026, 9, 30, 23, 59, 59) }
  let(:previous_month_end) { Time.utc(2026, 8, 31, 23, 59, 59) }

  let!(:latest_recording) { create_snapshot(group, month_end, recorded_at: Time.utc(2026, 10, 1, 3)) }
  let!(:earlier_recording) { create_snapshot(group, month_end, recorded_at: Time.utc(2026, 10, 1, 1)) }
  let!(:same_time_lower_id) { create_snapshot(other_group, month_end, recorded_at: Time.utc(2026, 10, 1, 2)) }
  let!(:same_time_higher_id) { create_snapshot(other_group, month_end, recorded_at: Time.utc(2026, 10, 1, 2)) }
  let!(:previous_month_snapshot) do
    create_snapshot(group, previous_month_end, recorded_at: Time.utc(2026, 9, 1, 1))
  end

  describe '#up' do
    it 'keeps the newest row per namespace and month and leaves distinct rows alone' do
      migrate!

      expect(snapshots.pluck(:id)).to contain_exactly(
        latest_recording.id, same_time_higher_id.id, previous_month_snapshot.id
      )
    end

    context 'when the duplicates span several batches' do
      before do
        stub_const("#{described_class}::BATCH_SIZE", 1)
      end

      it 'still keeps exactly one row per namespace and month' do
        migrate!

        expect(snapshots.pluck(:id)).to contain_exactly(
          latest_recording.id, same_time_higher_id.id, previous_month_snapshot.id
        )
      end
    end
  end

  def create_snapshot(namespace, end_time, recorded_at:)
    snapshots.create!(
      namespace_id: namespace.id,
      end_time: end_time,
      recorded_at: recorded_at,
      issue_opened: true,
      merge_request_opened: false,
      merge_request_approved: false,
      runner_configured: false,
      pipeline_succeeded: false,
      deploy_succeeded: false
    )
  end
end
