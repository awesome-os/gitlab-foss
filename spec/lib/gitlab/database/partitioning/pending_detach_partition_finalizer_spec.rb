# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Database::Partitioning::PendingDetachPartitionFinalizer, :clean_gitlab_redis_shared_state,
  feature_category: :database do
  include Database::PartitioningHelpers
  include Database::TableSchemaHelpers

  subject(:finalizer) { described_class.new }

  let(:connection) { ActiveRecord::Base.connection }
  let(:schema) { Gitlab::Database::DYNAMIC_PARTITIONS_SCHEMA }
  let(:referenced_table) { :_test_finalizer_referenced }
  let(:parent_table) { :_test_finalizer_referencing }

  # Mirrors p_ci_job_definition_instances: a partitioned table whose foreign key references another
  # partitioned table on the same key
  before do
    connection.execute(<<~SQL)
      CREATE TABLE #{referenced_table} (
        partition_id bigint NOT NULL,
        id bigserial NOT NULL,
        PRIMARY KEY (partition_id, id)
      ) PARTITION BY LIST (partition_id);

      CREATE TABLE #{schema}.#{referenced_table}_100 PARTITION OF #{referenced_table} FOR VALUES IN (100);
      CREATE TABLE #{schema}.#{referenced_table}_101 PARTITION OF #{referenced_table} FOR VALUES IN (101);

      CREATE TABLE #{parent_table} (
        partition_id bigint NOT NULL,
        id bigserial NOT NULL,
        referenced_id bigint NOT NULL,
        PRIMARY KEY (partition_id, id),
        CONSTRAINT fk_test_finalizer FOREIGN KEY (partition_id, referenced_id)
          REFERENCES #{referenced_table} (partition_id, id) ON DELETE CASCADE
      ) PARTITION BY LIST (partition_id);

      CREATE TABLE #{schema}.#{parent_table}_100 PARTITION OF #{parent_table} FOR VALUES IN (100);
      CREATE TABLE #{schema}.#{parent_table}_101 PARTITION OF #{parent_table} FOR VALUES IN (101);
    SQL
  end

  def pending?(name)
    Gitlab::Database::PostgresPartition.for_identifier("#{schema}.#{name}").pending_detach.exists?
  end

  def attached?(name)
    Gitlab::Database::PostgresPartition.for_identifier("#{schema}.#{name}").exists?
  end

  def schedule_drop(name)
    Postgresql::DetachedPartition.create!(table_name: name, drop_after: 1.week.from_now)
  end

  describe '#perform' do
    context 'when another DDL action holds the lease of the database' do
      let(:lease_key) { 'gitlab/database/asyncddl/actions/main' }

      before do
        mark_pending_detach("#{parent_table}_100")
        schedule_drop("#{parent_table}_100")
        Gitlab::ExclusiveLease.new(lease_key, timeout: 1.minute).try_obtain
      end

      it 'warns and leaves the partition pending' do
        expect(Gitlab::AppJsonLogger).to receive(:warn).with(hash_including(lease_key: lease_key))

        finalizer.perform

        expect(pending?("#{parent_table}_100")).to be(true)
      end
    end

    context 'when another DDL action holds the lease of the ci database' do
      let(:lease_key) { 'gitlab/database/asyncddl/actions/ci' }

      before do
        skip_if_shared_database(:ci)

        Gitlab::ExclusiveLease.new(lease_key, timeout: 1.minute).try_obtain
      end

      it 'warns with the lease key of the database it runs on' do
        expect(Gitlab::AppJsonLogger).to receive(:warn).with(hash_including(lease_key: lease_key))

        Gitlab::Database::SharedModel.using_connection(Ci::ApplicationRecord.connection) { finalizer.perform }
      end
    end

    context 'when two pending partitions of one parent table have scheduled drops' do
      before do
        %W[#{parent_table}_100 #{parent_table}_101].each do |name|
          mark_pending_detach(name)
          schedule_drop(name)
        end
      end

      # The second FINALIZE takes the lease of the parent table that the first one released
      it 'finalizes both' do
        finalizer.perform

        expect(attached?("#{parent_table}_100")).to be(false)
        expect(attached?("#{parent_table}_101")).to be(false)
      end
    end

    context 'when the run ends' do
      let(:lease_keys) do
        ['gitlab/database/asyncddl/actions/main',
          Gitlab::Database::Partitioning::PartitionManager::MANAGEMENT_LEASE_KEY % parent_table]
      end

      before do
        mark_pending_detach("#{parent_table}_100")
        schedule_drop("#{parent_table}_100")
      end

      def lease_free?(key)
        Gitlab::ExclusiveLease.new(key, timeout: 1.minute).try_obtain.present?
      end

      it 'releases both leases after finalizing' do
        finalizer.perform

        expect(lease_keys).to all(satisfy { |key| lease_free?(key) })
      end

      it 'releases both leases when FINALIZE fails' do
        allow(connection).to receive(:execute).and_call_original
        allow(connection).to receive(:execute).with(/DETACH PARTITION .* FINALIZE/m)
          .and_raise(ActiveRecord::StatementInvalid, 'boom')

        finalizer.perform

        expect(pending?("#{parent_table}_100")).to be(true)
        expect(lease_keys).to all(satisfy { |key| lease_free?(key) })
      end
    end

    context 'when a pending partition has a scheduled drop' do
      before do
        mark_pending_detach("#{parent_table}_100")
        schedule_drop("#{parent_table}_100")
      end

      it 'finalizes only that partition and keeps its table for the dropper' do
        finalizer.perform

        # A fully detached partition is absent from the view but its table still exists
        expect(attached?("#{parent_table}_100")).to be(false)
        expect(table_oid("#{parent_table}_100")).not_to be_nil
        expect(attached?("#{parent_table}_101")).to be(true)
      end
    end

    context 'when a pending partition has no scheduled drop' do
      before do
        mark_pending_detach("#{parent_table}_100")
      end

      it 'leaves it pending and warns' do
        allow(Gitlab::AppLogger).to receive(:warn)
        expect(Gitlab::AppLogger).to receive(:warn).with(hash_including(
          'message' => 'Skipped finalizing a pending detach partition without a scheduled drop',
          'partition_name' => "#{parent_table}_100"
        ))

        finalizer.perform

        expect(pending?("#{parent_table}_100")).to be(true)
      end
    end

    context 'when finalizing one partition fails' do
      before do
        mark_pending_detach("#{parent_table}_100")
        mark_pending_detach("#{referenced_table}_101")
        schedule_drop("#{parent_table}_100")
        schedule_drop("#{referenced_table}_101")

        allow(connection).to receive(:execute).and_call_original
        allow(connection).to receive(:execute)
          .with(/DETACH PARTITION "#{schema}"\."#{parent_table}_100" FINALIZE/)
          .and_raise(ActiveRecord::StatementInvalid, 'boom')
      end

      it 'logs the error and finalizes the others' do
        allow(Gitlab::AppLogger).to receive(:error)
        expect(Gitlab::AppLogger).to receive(:error).with(hash_including(
          'message' => 'Failed to finalize a pending detach partition',
          'partition_name' => "#{parent_table}_100"
        ))

        finalizer.perform

        expect(pending?("#{parent_table}_100")).to be(true)
        expect(attached?("#{referenced_table}_101")).to be(false)
      end
    end

    context 'when finalizing a partition' do
      before do
        mark_pending_detach("#{parent_table}_100")
        schedule_drop("#{parent_table}_100")
      end

      it 'locks the referenced tables, then the parent, before finalizing' do
        allow(connection).to receive(:execute).and_call_original

        expect(connection).to receive(:execute)
          .with(/LOCK TABLE "public"\."#{referenced_table}" IN SHARE ROW EXCLUSIVE MODE/).ordered.and_call_original
        expect(connection).to receive(:execute)
          .with(/LOCK TABLE ONLY "public"\."#{parent_table}" IN SHARE UPDATE EXCLUSIVE MODE/).ordered.and_call_original
        expect(connection).to receive(:execute).with(/DETACH PARTITION .* FINALIZE/m).ordered.and_call_original

        finalizer.perform

        expect(attached?("#{parent_table}_100")).to be(false)
      end

      it 'logs the finalized partition' do
        allow(Gitlab::AppLogger).to receive(:info)
        expect(Gitlab::AppLogger).to receive(:info)
          .with(message: 'Finalized a pending detach partition', partition_name: "#{parent_table}_100")

        finalizer.perform
      end

      context 'when the partition manager holds the lease of the parent table' do
        before do
          lease_key = Gitlab::Database::Partitioning::PartitionManager::MANAGEMENT_LEASE_KEY % parent_table
          Gitlab::ExclusiveLease.new(lease_key, timeout: 1.minute).try_obtain
        end

        it 'warns and leaves the partition pending' do
          allow(Gitlab::AppLogger).to receive(:warn)
          expect(Gitlab::AppLogger).to receive(:warn).with(hash_including(
            'message' => 'Skipped finalizing a pending detach partition: ' \
              'the partition manager holds the lease of its parent table',
            'partition_name' => "#{parent_table}_100"
          ))

          finalizer.perform

          expect(pending?("#{parent_table}_100")).to be(true)
        end
      end

      context 'when another process finalized it while we waited for the locks' do
        before do
          finalized_elsewhere = false

          # Another process finalizes the partition once we have listed it as pending
          allow(Gitlab::Database::PostgresPartition).to receive(:pending_detach).and_wrap_original do |method|
            method.call.tap do |partitions|
              next if finalized_elsewhere

              partitions.load
              connection.exec_query(
                "ALTER TABLE #{parent_table} DETACH PARTITION #{schema}.#{parent_table}_100 FINALIZE"
              )
              finalized_elsewhere = true
            end
          end
        end

        it 'skips the FINALIZE without an error' do
          expect(connection).not_to receive(:execute).with(/FINALIZE/)
          expect(Gitlab::AppLogger).not_to receive(:info)
            .with(hash_including(message: 'Finalized a pending detach partition'))
          expect(Gitlab::AppLogger).not_to receive(:error)

          finalizer.perform
        end
      end
    end

    context 'when the partition references no other table' do
      before do
        mark_pending_detach("#{referenced_table}_100")
        schedule_drop("#{referenced_table}_100")
      end

      it 'locks only the parent before finalizing' do
        allow(connection).to receive(:execute).and_call_original

        expect(connection).not_to receive(:execute).with(/IN SHARE ROW EXCLUSIVE MODE/)
        expect(connection).to receive(:execute)
          .with(/LOCK TABLE ONLY "public"\."#{referenced_table}" IN SHARE UPDATE EXCLUSIVE MODE/).and_call_original

        finalizer.perform

        expect(attached?("#{referenced_table}_100")).to be(false)
      end
    end
  end
end
