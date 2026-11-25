# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ci::PartitionableFinder, feature_category: :continuous_integration do
  let_it_be(:project, freeze: true) { create(:project) }
  let_it_be(:pipeline, freeze: true) { create(:ci_pipeline, project: project) }

  let(:test_model_class) do
    Class.new(Ci::ApplicationRecord) do
      include Ci::PartitionableFinder

      self.table_name = :p_ci_pipelines
      self.primary_key = :id

      def self.name
        'TestPartitionableModel'
      end
    end
  end

  describe '.find_by_id' do
    context 'when the record is in the current partition' do
      before do
        allow(Ci::Partition)
          .to receive(:current)
          .and_return(build_stubbed(:ci_partition, id: pipeline.partition_id))
      end

      it 'finds the record with partition pruning' do
        expect(test_model_class.find_by_id(pipeline.id)&.id).to eq(pipeline.id)
      end

      it 'does only one query' do
        expect do
          test_model_class.find_by_id(pipeline.id)
        end.not_to exceed_query_limit(1).for_query(/SELECT.*p_ci_pipelines/)
      end
    end

    context 'when the record is not in the current partition' do
      before do
        allow(Ci::Partition)
          .to receive(:current)
          .and_return(build_stubbed(:ci_partition, id: non_existing_record_id))
      end

      context 'when the record is in the latest active partitions' do
        before do
          allow(Ci::Partition).to receive_message_chain(:with_status, :order, :limit, :pluck)
            .and_return([pipeline.partition_id])
        end

        it 'finds the record in active partitions and logs the fallback' do
          expect(Gitlab::AppLogger).to receive(:info).with(
            hash_including(
              message: 'Failed to find the record in the current partition',
              record_id: pipeline.id,
              'class_name' => 'TestPartitionableModel'
            )
          )

          expect(test_model_class.find_by_id(pipeline.id)&.id).to eq(pipeline.id)
        end

        it 'does two queries' do
          expect do
            test_model_class.find_by_id(pipeline.id)
          end.not_to exceed_query_limit(2).for_query(/SELECT.*p_ci_pipelines/)
        end
      end

      context 'when the record is not in the latest active partitions' do
        before do
          allow(Ci::Partition).to receive_message_chain(:with_status, :order, :limit, :pluck)
            .and_return([non_existing_record_id])
        end

        it 'falls back on the full table and logs both fallbacks' do
          expect(Gitlab::AppLogger).to receive(:info).with(
            hash_including(
              message: 'Failed to find the record in the current partition',
              record_id: pipeline.id,
              'class_name' => 'TestPartitionableModel'
            )
          )
          expect(Gitlab::AppLogger).to receive(:info).with(
            hash_including(
              message: 'Failed to find the record in the latest active partitions',
              record_id: pipeline.id,
              'class_name' => 'TestPartitionableModel'
            )
          )

          expect(test_model_class.find_by_id(pipeline.id)&.id).to eq(pipeline.id)
        end

        it 'does three queries' do
          expect do
            test_model_class.find_by_id(pipeline.id)
          end.not_to exceed_query_limit(3).for_query(/SELECT.*p_ci_pipelines/)
        end
      end
    end

    it 'returns nil when record not found' do
      result = test_model_class.find_by_id(non_existing_record_id)
      expect(result).to be_nil
    end

    context 'with the current partition id cache' do
      before do
        Ci::Partition.find_or_create_by!(id: pipeline.partition_id).update!(status: Ci::Partition.statuses[:current])
      end

      it 'reads the current partition once across lookups' do
        test_model_class.find_by_id(pipeline.id)

        recorder = ActiveRecord::QueryRecorder.new(skip_cached: false) { test_model_class.find_by_id(pipeline.id) }

        expect(recorder.log).to contain_exactly(/p_ci_pipelines/)
      end

      it 'finds a record outside the cached partition through the fallbacks' do
        test_model_class.find_by_id(pipeline.id)
        allow(Ci::Partition).to receive(:cached_current_id).and_return(non_existing_record_id)

        expect(test_model_class.find_by_id(pipeline.id)&.id).to eq(pipeline.id)
      end

      context 'when ci_partition_current_cache is disabled' do
        before do
          stub_feature_flags(ci_partition_current_cache: false)
        end

        it 'reads the current partition on every lookup' do
          test_model_class.find_by_id(pipeline.id)

          recorder = ActiveRecord::QueryRecorder.new(skip_cached: false) { test_model_class.find_by_id(pipeline.id) }

          expect(recorder.log).to contain_exactly(/ci_partitions/, /p_ci_pipelines/)
        end

        it 'finds the record through the fallbacks without a current partition' do
          allow(Ci::Partition).to receive(:current).and_return(nil)

          expect(test_model_class.find_by_id(pipeline.id)&.id).to eq(pipeline.id)
        end
      end
    end
  end
end
