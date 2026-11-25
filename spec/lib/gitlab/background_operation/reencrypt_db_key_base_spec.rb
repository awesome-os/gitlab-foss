# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::BackgroundOperation::ReencryptDbKeyBase, feature_category: :cell do
  include DbKeyBaseHelpers

  let_it_be(:project) { create(:project) }

  # Read before any example stubs the keys
  let!(:old_key) { Settings.db_key_base_keys.last }
  let(:new_key) { SecureRandom.hex(64) }

  def build_operation(
    operation_class, table_name, cursor_range,
    connection: ApplicationRecord.connection, rotation_id: described_class.current_rotation_id)
    operation_class.new(
      min_cursor: [cursor_range.begin],
      max_cursor: [cursor_range.end],
      batch_table: table_name,
      batch_column: operation_class.cursor_columns.first,
      sub_batch_size: 2,
      pause_ms: 0,
      connection: connection,
      job_arguments: [rotation_id]
    )
  end

  def create_hook(key)
    create_with_key(key) { create(:project_hook, project: project, url: 'https://example.com/hook') }
  end

  describe '.current_rotation_id' do
    it 'differs for every ordered set of keys' do
      ids = [[old_key, new_key], [new_key, old_key], [new_key]].map do |keys|
        stub_db_key_base_keys(*keys)
        described_class.current_rotation_id
      end

      expect(ids.uniq.size).to eq(3)
    end

    it 'is the same for the same keys' do
      stub_db_key_base_keys(old_key, new_key)
      id = described_class.current_rotation_id

      stub_db_key_base_keys(old_key.dup, new_key.dup)

      expect(described_class.current_rotation_id).to eq(id).and match(/\A\h{16}\z/)
    end

    it 'digests keys that are not valid UTF-8' do
      stub_db_key_base_keys(old_key, "#{new_key}\xFF".b)

      expect(described_class.current_rotation_id).to match(/\A\h{16}\z/)
    end
  end

  describe '.job_class_name' do
    it 'names a class whose cursor is the primary key, for every table to re-encrypt' do
      Gitlab::Encryption::DbKeyBaseRotation::Registry.tables.each do |table|
        operation_class = "Gitlab::BackgroundOperation::#{described_class.job_class_name(table)}".constantize

        expect(operation_class.cursor_columns).to eq([table.key_columns.first.to_sym]), table.name
      end
    end
  end

  describe '#perform' do
    context 'with rows on the old key and on the current key' do
      let!(:old_hooks) { Array.new(2) { create_hook(old_key) } }
      let!(:new_hook) { create_hook(new_key) }
      let!(:outside_hook) { create_hook(old_key) }

      let(:operation) { build_operation(described_class, 'web_hooks', old_hooks.first.id..new_hook.id) }

      before do
        stub_db_key_base_keys(old_key, new_key)
      end

      it 're-encrypts the rows on the old key within the cursors', :aggregate_failures do
        operation.perform

        expect(WebHook.where(id: old_hooks).map { |hook| hook.attr_encrypted_encrypted_with(:url) })
          .to all(eq(:current))
        expect(WebHook.find(outside_hook.id).attr_encrypted_encrypted_with(:url)).to eq(:previous)
      end

      it 'records the count of each outcome in the job metrics' do
        operation.perform

        expect(operation.batch_metrics.affected_rows)
          .to eq(update_all: [2, 0], skipped: [0, 1], conflict: [0, 0], error: [0, 0])
      end

      it 'does not log when no row is left behind' do
        expect(Gitlab::AppLogger).not_to receive(:info)

        operation.perform
      end
    end

    context 'with a row that no key decrypts' do
      let!(:hook) { create_hook(SecureRandom.hex(64)) }

      before do
        stub_db_key_base_keys(old_key, new_key)
        allow(Gitlab::ErrorTracking).to receive(:track_exception)
      end

      it 'logs the counts of the job' do
        expect(Gitlab::AppLogger).to receive(:info).with(
          Labkit::Fields::CLASS_NAME => described_class.name,
          Labkit::Fields::LOG_MESSAGE => 'db_key_base_reencryption_rows_left',
          table_name: 'web_hooks',
          rotation_id: described_class.current_rotation_id,
          reencrypted_count: 0, skipped_count: 0, conflict_count: 0, error_count: 1
        )

        build_operation(described_class, 'web_hooks', hook.id..hook.id).perform
      end
    end

    context 'with a row edited during the job' do
      it 'logs the conflict' do
        hook = create_hook(old_key)
        stub_db_key_base_keys(old_key, new_key)
        allow_next_instance_of(Gitlab::Encryption::DbKeyBaseRotation::TableReencryptor) do |reencryptor|
          allow(reencryptor).to receive(:reencrypt)
            .and_return(Gitlab::Encryption::DbKeyBaseRotation::TableReencryptor::Counts.new(0, 0, 1, 0))
        end

        expect(Gitlab::AppLogger).to receive(:info)
          .with(a_hash_including(conflict_count: 1, error_count: 0))

        build_operation(described_class, 'web_hooks', hook.id..hook.id).perform
      end
    end

    context 'when the cursors hold no rows' do
      it 'counts nothing' do
        operation = build_operation(described_class, 'web_hooks', non_existing_record_id..non_existing_record_id)

        operation.perform

        expect(operation.batch_metrics.affected_rows).to eq(update_all: [0], skipped: [0], conflict: [0], error: [0])
      end
    end

    context 'when the keys are not the ones of the rotation' do
      it 'raises before re-encrypting anything', :aggregate_failures do
        hook = create_hook(old_key)
        stub_db_key_base_keys(old_key, new_key)
        operation = build_operation(described_class, 'web_hooks', hook.id..hook.id, rotation_id: 'abcd')

        expect { operation.perform }.to raise_error(described_class::RotationMismatchError,
          "the current db_key_base rotation is #{described_class.current_rotation_id}, not abcd")
        expect(WebHook.find(hook.id).attr_encrypted_encrypted_with(:url)).to eq(:previous)
      end
    end

    context 'when the connection is not the table\'s database' do
      it 'raises' do
        skip_if_shared_database(:ci)

        expect { build_operation(described_class, 'p_ci_builds', 1..1).perform }
          .to raise_error(ArgumentError, 'p_ci_builds is in gitlab_ci, which the main database does not serve')
      end
    end

    context 'when the cursor is not the first column of the table\'s primary key' do
      it 'raises' do
        expect { build_operation(described_class, 'project_error_tracking_settings', 1..1).perform }
          .to raise_error(ArgumentError, 'project_error_tracking_settings is keyed on project_id, not on id; ' \
            'enqueue ReencryptDbKeyBaseByProjectId')
      end
    end

    context 'with a table keyed on project_id' do
      it 're-encrypts its rows' do
        setting = create_with_key(old_key) { create(:project_error_tracking_setting, project: project) }
        stub_db_key_base_keys(old_key, new_key)

        build_operation(Gitlab::BackgroundOperation::ReencryptDbKeyBaseByProjectId,
          'project_error_tracking_settings', project.id..project.id).perform

        expect(ErrorTracking::ProjectErrorTrackingSetting.find(setting.project_id).attr_encrypted_encrypted_with(:token))
          .to eq(:current)
      end
    end

    context 'with job tokens of the partitioned builds table' do
      let_it_be(:pipeline) { create(:ci_pipeline, project: project) }

      let!(:builds) do
        create_with_key(old_key) do
          [:running, :success, :running].map { |status| create(:ci_build, status, pipeline: pipeline) }
        end
      end

      let(:operation) do
        build_operation(described_class, 'p_ci_builds', builds.first.id..builds.last.id,
          connection: Ci::ApplicationRecord.connection)
      end

      before do
        stub_db_key_base_keys(old_key, new_key)
      end

      it 're-encrypts the tokens of unfinished builds on the CI connection', :aggregate_failures do
        operation.perform

        expect(Ci::Build.where(id: builds.values_at(0, 2)).order(:id).map(&:token_encrypted))
          .to eq(builds.values_at(0, 2).map { |build| Authn::TokenField::EncryptionHelper.encrypt_token(build.token) })
        expect(Ci::Build.find(builds.second.id).token_encrypted).to eq(builds.second.token_encrypted)
      end

      it 'only reads the unfinished builds of each sub-batch' do
        operation.perform

        expect(operation.batch_metrics.affected_rows)
          .to eq(update_all: [1, 1], skipped: [0, 0], conflict: [0, 0], error: [0, 0])
      end

      it 'reads the rows of the partitions of the sub-batch only', :aggregate_failures do
        recorder = ActiveRecord::QueryRecorder.new { operation.perform }
        reads = recorder.log.grep(/"token_encrypted" IS NOT NULL/)

        expect(reads.size).to eq(2)
        expect(reads).to all(include(%("p_ci_builds"."partition_id" = #{builds.first.partition_id})))
      end

      it 'counts nothing when the rows of a sub-batch are deleted before it is read' do
        allow(operation).to receive(:each_sub_batch).and_wrap_original do |method, &block|
          method.call do |sub_batch|
            Ci::Build.where(id: builds.map(&:id)).delete_all
            block.call(sub_batch)
          end
        end

        operation.perform

        expect(operation.batch_metrics.affected_rows)
          .to eq(update_all: [0, 0], skipped: [0, 0], conflict: [0, 0], error: [0, 0])
      end
    end

    context 'with a table that has no column encrypted with db_key_base' do
      it 'raises' do
        expect { build_operation(described_class, 'emails', 1..1).perform }
          .to raise_error(ArgumentError, 'emails has no column encrypted with db_key_base')
      end
    end
  end
end
