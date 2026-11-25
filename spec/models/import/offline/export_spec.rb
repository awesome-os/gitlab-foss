# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Import::Offline::Export, feature_category: :importers do
  using RSpec::Parameterized::TableSyntax

  describe 'associations' do
    it { is_expected.to belong_to(:user) }
    it { is_expected.to belong_to(:organization) }
    it { is_expected.to have_one(:configuration).class_name('Import::Offline::Configuration') }
    it { is_expected.to have_many(:bulk_import_exports).class_name('BulkImports::Export') }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:status) }
  end

  describe '#source_hostname' do
    it 'returns the configuration source hostname' do
      source_hostname = 'https://gitlab.example.com'
      configuration = build(:offline_configuration, source_hostname: source_hostname)
      export = build(:offline_export, configuration: configuration)

      expect(export.source_hostname).to eq(source_hostname)
    end
  end

  describe 'scopes' do
    describe '.including_user_and_organization' do
      it 'preloads users and organizations for the selected exports', :aggregate_failures do
        first_export = create(:offline_export)
        second_export = create(:offline_export)
        exports = described_class.where(id: [first_export.id, second_export.id])
          .including_user_and_organization.to_a

        recorder = ActiveRecord::QueryRecorder.new(skip_cached: false) do
          exports.each do |export|
            export.user
            export.organization
          end
        end

        expect(exports).to contain_exactly(first_export, second_export)
        expect(recorder.log).to be_empty
      end
    end

    describe '.order_by_updated_at_and_id' do
      let_it_be(:newer_export) { create(:offline_export, :started, updated_at: 25.hours.ago) }
      let_it_be(:older_export) { create(:offline_export, :started, updated_at: 2.days.ago) }
      let_it_be(:same_time_export) { create(:offline_export, :created, updated_at: older_export.updated_at) }

      it 'orders exports by updated_at ascending and uses id to break ties' do
        expect(described_class.order_by_updated_at_and_id(:asc)).to eq([older_export, same_time_export, newer_export])
      end

      it 'orders exports by updated_at descending and uses id ascending to break ties' do
        expect(described_class.order_by_updated_at_and_id(:desc)).to eq([newer_export, older_export, same_time_export])
      end
    end

    describe '.stale_candidates', :freeze_time do
      it 'uses the model staleness threshold when no cutoff is provided' do
        stale_export = create(:offline_export, :started, updated_at: 25.hours.ago)
        create(:offline_export, :started, updated_at: 23.hours.ago)
        create(:offline_export, :finished, updated_at: 2.days.ago)
        create(:offline_export, :failed, updated_at: 2.days.ago)
        create(:offline_export, :created, updated_at: 24.hours.ago)
        create(:offline_export, :started, updated_at: 24.hours.ago)

        expect(described_class.stale_candidates).to contain_exactly(stale_export)
        expect(described_class.stale_candidates(26.hours.ago)).to be_empty
      end
    end

    describe '.order_by_created_at' do
      let_it_be(:export_1) { create(:offline_export, created_at: 3.days.ago) }
      let_it_be(:export_2) { create(:offline_export, created_at: 2.days.ago) }
      let_it_be(:export_3) { create(:offline_export, created_at: 1.day.ago) }

      it 'orders exports by created_at in ascending order' do
        expect(described_class.order_by_created_at(:asc)).to eq([export_1, export_2, export_3])
      end

      it 'orders exports by created_at in descending order' do
        expect(described_class.order_by_created_at(:desc)).to eq([export_3, export_2, export_1])
      end
    end
  end

  describe '.all_human_statuses' do
    it 'returns all human readable entity statuses' do
      expect(described_class.all_human_statuses)
        .to contain_exactly('created', 'started', 'finished', 'failed')
    end
  end

  describe 'configuration purge' do
    let_it_be_with_reload(:export) { create(:offline_export, :started) }
    let_it_be(:configuration) { create(:offline_configuration, offline_export: export) }

    describe 'after transitioning to finished' do
      it 'schedules configuration purge worker' do
        expect(Import::Offline::ConfigurationPurgeWorker)
          .to receive(:perform_in)
          .with(described_class::PURGE_CONFIGURATION_DELAY, configuration.id)

        export.finish
      end

      context 'when export has no configuration' do
        let_it_be_with_reload(:export_without_config) { create(:offline_export) }

        it 'does not schedule configuration purge worker' do
          expect(Import::Offline::ConfigurationPurgeWorker).not_to receive(:perform_in)

          export_without_config.finish
        end
      end
    end

    describe 'after transitioning to failed' do
      it 'schedules configuration purge worker' do
        expect(Import::Offline::ConfigurationPurgeWorker)
          .to receive(:perform_in)
          .with(described_class::PURGE_CONFIGURATION_DELAY, configuration.id)

        export.fail_op
      end

      context 'when export has no configuration' do
        let_it_be_with_reload(:export_without_config) { create(:offline_export) }

        it 'does not schedule configuration purge worker' do
          export_without_config.start

          expect(Import::Offline::ConfigurationPurgeWorker).not_to receive(:perform_in)

          export_without_config.fail_op
        end
      end
    end
  end

  describe 'email notification' do
    let_it_be_with_reload(:export) { create(:offline_export, :started) }
    let_it_be(:configuration) { create(:offline_configuration, offline_export: export) }

    describe 'after transitioning to finished' do
      let(:mail) { instance_double(ActionMailer::MessageDelivery, deliver_later: true) }

      it 'sends offline_export_complete email' do
        expect(Notify).to receive(:offline_export_complete).with(export.user_id, export.id).and_return(mail)

        export.finish
      end
    end

    describe 'after transitioning to failed' do
      let(:mail) { instance_double(ActionMailer::MessageDelivery, deliver_later: true) }

      it 'sends offline_export_failed email' do
        expect(Notify).to receive(:offline_export_failed).with(export.user_id, export.id).and_return(mail)

        export.fail_op
      end
    end
  end

  describe 'internal events tracking', :clean_gitlab_redis_shared_state do
    let_it_be_with_reload(:export) { create(:offline_export, :started) }

    describe 'after transitioning to finished' do
      context 'when the export finished without failures' do
        it 'tracks a complete event with the without_failures label' do
          expect { export.finish }
            .to trigger_internal_events('complete_offline_transfer_export')
            .with(user: export.user, additional_properties: { label: 'without_failures' })
            .and increment_usage_metrics(
              'counts.count_total_complete_offline_transfer_export',
              'counts.count_total_complete_offline_transfer_export_monthly'
            ).and not_increment_usage_metrics(
              'counts.count_total_complete_offline_transfer_export_with_failures',
              'counts.count_total_complete_offline_transfer_export_with_failures_monthly'
            )
        end
      end

      context 'when the export finished with failures' do
        before do
          export.update!(has_failures: true)
        end

        it 'tracks a complete event with the with_failures label' do
          expect { export.finish }
            .to trigger_internal_events('complete_offline_transfer_export')
            .with(user: export.user, additional_properties: { label: 'with_failures' })
            .and increment_usage_metrics(
              'counts.count_total_complete_offline_transfer_export',
              'counts.count_total_complete_offline_transfer_export_monthly',
              'counts.count_total_complete_offline_transfer_export_with_failures',
              'counts.count_total_complete_offline_transfer_export_with_failures_monthly'
            )
        end
      end

      describe 'when the export fails' do
        it 'tracks a fail event' do
          expect { export.fail_op }
            .to trigger_internal_events('fail_offline_transfer_export')
            .with(user: export.user)
            .and increment_usage_metrics(
              'counts.count_total_fail_offline_transfer_export',
              'counts.count_total_fail_offline_transfer_export_monthly'
            )
        end
      end
    end
  end

  describe '#completed?' do
    where(:status_trait, :expected_result) do
      :created  | false
      :started  | false
      :finished | true
      :failed   | true
    end

    with_them do
      subject(:export) { build(:offline_export, status_trait) }

      it 'returns the expected result' do
        expect(export.completed?).to eq(expected_result)
      end
    end
  end

  describe '#stale?', :freeze_time do
    let_it_be(:group) { create(:group) }
    let(:export) do
      create(:offline_export, status, created_at: 3.days.ago, updated_at: export_age.hours.ago)
    end

    where(:status, :export_age, :relation_age, :expected) do
      :created  | 25 | nil | true
      :started  | 25 | nil | true
      :created  | 1  | nil | false
      :started  | 24 | nil | false
      :finished | 25 | nil | false
      :failed   | 25 | nil | false
      :started  | 25 | 1   | false
      :started  | 25 | 24  | false
      :started  | 25 | 25  | true
    end

    with_them do
      before do
        if relation_age
          create(:bulk_import_export, group: group, offline_export: export,
            created_at: 3.days.ago, updated_at: relation_age.hours.ago)
        end
      end

      it 'checks activity on the offline export and its relation exports', :aggregate_failures do
        expect(export.stale?(24.hours.ago)).to eq(expected)
        expect(export.stale?).to eq(expected)
      end
    end
  end

  describe '#update_has_failures!' do
    context 'when has_failures is currently false' do
      subject(:export) { create(:offline_export, has_failures: false) }

      it 'sets the has_failures flag to true' do
        expect { export.update_has_failures! }
          .to change { export.has_failures }
          .from(false).to(true)
      end
    end

    context 'when has_failures is currently true' do
      subject(:export) { build_stubbed(:offline_export, has_failures: true) }

      it 'leaves the has_failures flag unchanged' do
        expect { export.update_has_failures! }
          .not_to change { export.has_failures }
      end
    end
  end

  describe 'included routes methods' do
    let_it_be_with_reload(:export) { create(:offline_export) }
    let_it_be(:included_project_1) { create(:project) }
    let_it_be(:included_project_2) { create(:project) }
    let_it_be(:excluded_project) { create(:project) }
    let_it_be(:included_group_1) { create(:group) }
    let_it_be(:included_group_2) { create(:group) }
    let_it_be(:excluded_group) { create(:group) }

    before_all do
      # Create finished group and project relations belonging to offline_export
      create(:bulk_import_export, :finished, offline_export: export, project: included_project_1)
      create(:bulk_import_export, :finished, offline_export: export, project: included_project_2)
      create(:bulk_import_export, :finished, offline_export: export, group: included_group_1)
      create(:bulk_import_export, :finished, offline_export: export, group: included_group_2)

      # Create group and project relation exports not in finished status
      create(:bulk_import_export, :pending, offline_export: export, project: excluded_project, relation: 'milestones')
      create(:bulk_import_export, :started, offline_export: export, project: excluded_project, relation: 'issues')
      create(:bulk_import_export, :failed, offline_export: export, project: excluded_project, relation: 'snippets')
      create(:bulk_import_export, :pending, offline_export: export, group: excluded_group, relation: 'milestones')
      create(:bulk_import_export, :started, offline_export: export, group: excluded_group, relation: 'badges')
      create(:bulk_import_export, :failed, offline_export: export, group: excluded_group, relation: 'boards')

      # Create finished group and project relation exports for other offline exports
      create(:bulk_import_export, :offline, :finished, project: excluded_project)
      create(:bulk_import_export, :offline, :finished, group: excluded_group)
    end

    describe '#included_group_routes' do
      subject(:included_group_routes) { export.included_group_routes }

      it 'returns group routes for finished group relation exports belonging to the offline export' do
        expect(included_group_routes).to contain_exactly(included_group_1.route, included_group_2.route)
      end
    end

    describe '#included_project_routes' do
      subject(:included_project_routes) { export.included_project_routes }

      it 'returns project routes for finished project relation exports belonging to the offline export' do
        expect(included_project_routes).to contain_exactly(included_project_1.route, included_project_2.route)
      end
    end
  end
end
