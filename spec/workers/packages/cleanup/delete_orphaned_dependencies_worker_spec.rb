# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Packages::Cleanup::DeleteOrphanedDependenciesWorker, feature_category: :package_registry do
  let(:worker) { described_class.new }

  it { is_expected.to include_module(CronjobQueue) }
  it { expect(described_class.idempotent?).to be_truthy }

  describe '#perform', :clean_gitlab_redis_shared_state do
    let_it_be(:orphaned_dependencies) { create_list(:packages_dependency, 2) }
    let_it_be(:linked_dependency) do
      create(:packages_dependency).tap do |dependency|
        create(:packages_dependency_link, dependency: dependency)
      end
    end

    subject { worker.perform }

    it 'deletes only orphaned dependencies' do
      expect { subject }.to change { Packages::Dependency.count }.by(-2)
      expect(Packages::Dependency.all).to contain_exactly(linked_dependency)
    end

    it 'executes 3 queries' do
      queries = ActiveRecord::QueryRecorder.new { subject }

      # each_batch lower and upper bound selects, then the delete of dependencies without links.
      expect(queries.count).to eq(3)
    end

    context 'when the worker is running for more than the max time' do
      before do
        allow(worker).to receive(:over_time?).and_return(true)
      end

      it 'sets the last processed dependency id in redis cache' do
        subject

        Gitlab::Redis::SharedState.with do |redis|
          expect(redis.get('last_processed_packages_dependency_id').to_i).to eq(Packages::Dependency.last.id)
        end
      end
    end

    context 'when the worker reaches the maximum number of batches' do
      before do
        stub_const('Packages::Cleanup::DeleteOrphanedDependenciesWorker::MAX_BATCHES', 1)
      end

      it 'iterates over only 1 batch' do
        expect { subject }.to change { Packages::Dependency.count }.by(-2)
      end

      it 'sets the last processed dependency id in redis cache' do
        subject

        Gitlab::Redis::SharedState.with do |redis|
          expect(redis.get('last_processed_packages_dependency_id').to_i).to eq(Packages::Dependency.last.id)
        end
      end
    end

    context 'when the worker finishes processing in less than the max time' do
      before do
        Gitlab::Redis::SharedState.with do |redis|
          redis.set('last_processed_packages_dependency_id', orphaned_dependencies.first.id)
        end
      end

      it 'clears the last processed last_processed_packages_dependency_id from redis cache' do
        Gitlab::Redis::SharedState.with do |redis|
          expect { subject }
            .to change { redis.get('last_processed_packages_dependency_id') }.to(nil)
        end
      end
    end

    context 'when logging extra metadata' do
      before do
        stub_const('Packages::Cleanup::DeleteOrphanedDependenciesWorker::MAX_BATCHES', 1)
      end

      it 'logs the last proccessed id & the deleted rows count', :aggregate_failures do
        expect(worker).to receive(:log_extra_metadata_on_done).with(
          :last_processed_packages_dependency_id,
          Packages::Dependency.last.id
        )
        expect(worker).to receive(:log_extra_metadata_on_done).with(:deleted_rows_count, 2)

        subject
      end
    end
  end
end
