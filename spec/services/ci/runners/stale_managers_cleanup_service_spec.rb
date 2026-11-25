# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ci::Runners::StaleManagersCleanupService, :clean_gitlab_redis_shared_state, feature_category: :fleet_visibility do
  let(:service) { described_class.new }
  let!(:runner_manager3) { create(:ci_runner_machine, created_at: 6.months.ago, contacted_at: Time.current) }

  subject(:response) { service.execute }

  context 'when stale_runner_manager_cleanup_by_partition is disabled' do
    before do
      stub_feature_flags(stale_runner_manager_cleanup_by_partition: false)
    end

    context 'with no stale runner managers' do
      it 'does not clean any runner managers and returns :success status' do
        expect do
          expect(response).to be_success
          expect(response.payload).to match({ total_deleted: 0, batch_counts: [0] })
        end.not_to change { Ci::RunnerManager.count }.from(1)
      end
    end

    context 'with some stale runner managers' do
      before do
        create(:ci_runner_machine, :stale)
        create(:ci_runner_machine, :stale, contacted_at: nil)
      end

      it 'only leaves non-stale runners' do
        expect(response).to be_success
        expect(response.payload).to match({ total_deleted: 2, batch_counts: [2, 0] })
        expect(Ci::RunnerManager.all).to contain_exactly(runner_manager3)
      end

      context 'with more stale runners than SUB_BATCH_LIMIT' do
        before do
          stub_const("#{described_class}::SUB_BATCH_LIMIT", 1)
        end

        it 'only leaves non-stale runners' do
          expect(response).to be_success
          expect(response.payload).to match({ total_deleted: 2, batch_counts: [1, 1, 0] })
          expect(Ci::RunnerManager.all).to contain_exactly(runner_manager3)
        end
      end

      context 'with more stale runners than MAX_DELETIONS' do
        before do
          stub_const("#{described_class}::MAX_DELETIONS", 1)
        end

        it 'only leaves non-stale runners' do
          expect do
            expect(response).to be_success
            expect(response.payload).to match({
              total_deleted: Ci::Runners::StaleManagersCleanupService::MAX_DELETIONS,
              batch_counts: [1]
            })
          end.to change { Ci::RunnerManager.count }.by(-Ci::Runners::StaleManagersCleanupService::MAX_DELETIONS)
        end
      end

      it 'runs at most once per LEGACY_INTERVAL' do
        expect(described_class.new.execute.payload).to include(total_deleted: 2)

        create(:ci_runner_machine, :stale)

        expect { expect(described_class.new.execute.payload).to eq({ skipped: true }) }
          .not_to change { Ci::RunnerManager.count }
      end
    end
  end

  context 'when stale_runner_manager_cleanup_by_partition is enabled' do
    let_it_be(:project_runner) { create(:ci_runner, :project, projects: [create(:project)]) }
    let_it_be(:group_runner) { create(:ci_runner, :group, groups: [create(:group)]) }

    let(:deletions_per_run) { 500 }
    let(:lfk_pending_limit) { 5_000 }

    before do
      stub_application_setting(
        ci_stale_runner_managers_cleanup_deletions_per_run: deletions_per_run,
        ci_stale_runner_managers_cleanup_backlog_limit: lfk_pending_limit
      )
    end

    context 'with no stale runner managers' do
      it 'deletes nothing' do
        expect { expect(response.payload).to include(total_deleted: 0) }.not_to change { Ci::RunnerManager.count }
        expect(response.payload).not_to have_key(:stop_reason)
      end
    end

    context 'with stale runner managers of every runner type' do
      let!(:instance_managers) { create_list(:ci_runner_machine, 2, :stale) }
      let!(:group_managers) { create_list(:ci_runner_machine, 2, :stale, runner: group_runner) }
      let!(:project_managers) { create_list(:ci_runner_machine, 3, :stale, runner: project_runner, contacted_at: nil) }

      it 'deletes the stale managers of every runner type' do
        expect(response).to be_success
        expect(response.payload).to include(
          total_deleted: 7,
          deleted_by_runner_type: { 'instance_type' => 2, 'group_type' => 2, 'project_type' => 3 }
        )
        expect(response.payload).not_to have_key(:stop_reason)
        expect(Ci::RunnerManager.all).to contain_exactly(runner_manager3)
      end

      context 'when the budget is used up' do
        let(:deletions_per_run) { 4 }

        # The next run time at which the rotation starts at the first runner type. Going back in time, even by the
        # microseconds that `travel_to` drops, would make the stale managers not stale yet.
        let(:run_at) do
          time = 1.minute.from_now
          time + ((3 - ((time.to_i / 10.minutes.to_i) % 3)) % 3 * 10.minutes)
        end

        before do
          stub_const("#{described_class}::SUB_BATCH_LIMIT", 1)
        end

        it 'takes one batch from each runner type in turn' do
          travel_to(run_at) do
            expect(service.execute.payload).to include(
              total_deleted: 4,
              deleted_by_runner_type: { 'instance_type' => 2, 'group_type' => 1, 'project_type' => 1 },
              stop_reason: :budget
            )
          end
        end

        context 'when a full batch deletes fewer managers than it selected' do
          let(:deletions_per_run) { 5 }

          before do
            first_project_batch = true

            allow(Ci::RunnerManager).to receive(:delete_stale).and_wrap_original do |original, **kwargs|
              if kwargs[:runner_type] == 'project_type' && first_project_batch
                first_project_batch = false
                next [1, 0]
              end

              original.call(**kwargs)
            end
          end

          it 'keeps the runner type in the rotation' do
            travel_to(run_at) do
              expect(service.execute.payload).to include(
                total_deleted: 5,
                deleted_by_runner_type: { 'instance_type' => 2, 'group_type' => 2, 'project_type' => 1 }
              )
            end
          end
        end

        it 'starts the next run at the next runner type' do
          travel_to(run_at + 10.minutes) do
            expect(service.execute.payload).to include(
              total_deleted: 4,
              deleted_by_runner_type: { 'instance_type' => 1, 'group_type' => 2, 'project_type' => 1 }
            )
          end
        end
      end

      context 'when loose foreign key records are pending above the limit' do
        before do
          allow_next_instance_of(Ci::Runners::LooseForeignKeysBacklog) do |backlog|
            allow(backlog).to receive(:pending_count).and_return(0)
            allow(backlog).to receive(:over_limit?).with(lfk_pending_limit).and_return(true)
          end
        end

        it 'deletes nothing' do
          expect { expect(response.payload).to include(total_deleted: 0, stop_reason: :loose_foreign_keys) }
            .not_to change { Ci::RunnerManager.count }
        end
      end

      context 'when the runner manager cap has a lower loose foreign key limit' do
        before do
          stub_application_setting(ci_runner_manager_cap_cleanup_backlog_limit: 1_000)
        end

        it 'stops at the lower limit' do
          expect_next_instance_of(Ci::Runners::LooseForeignKeysBacklog) do |backlog|
            allow(backlog).to receive(:pending_count).and_return(0)
            expect(backlog).to receive(:over_limit?).with(1_000).and_return(true)
          end

          expect(response.payload).to include(stop_reason: :loose_foreign_keys)
        end
      end

      context 'when the run is over time' do
        before do
          allow_next_instance_of(Gitlab::Metrics::RuntimeLimiter) do |limiter|
            allow(limiter).to receive(:over_time?).and_return(true)
          end
        end

        it 'deletes nothing' do
          expect { expect(response.payload).to include(total_deleted: 0, stop_reason: :runtime) }
            .not_to change { Ci::RunnerManager.count }
        end
      end
    end

    it 'logs the pending loose foreign key records' do
      allow_next_instance_of(Ci::Runners::LooseForeignKeysBacklog) do |backlog|
        allow(backlog).to receive(:pending_count).and_call_original
        allow(backlog).to receive(:pending_count).with(limit: lfk_pending_limit * 10).and_return(42)
      end

      expect(response.payload).to include(lfk_pending_records: 42)
    end

    it 'leaves the pending count out when counting times out' do
      allow_next_instance_of(Ci::Runners::LooseForeignKeysBacklog) do |backlog|
        allow(backlog).to receive(:pending_count).and_call_original
        allow(backlog).to receive(:pending_count).with(limit: lfk_pending_limit * 10)
          .and_raise(ActiveRecord::QueryCanceled)
      end

      expect(response.payload).not_to have_key(:lfk_pending_records)
    end
  end
end
