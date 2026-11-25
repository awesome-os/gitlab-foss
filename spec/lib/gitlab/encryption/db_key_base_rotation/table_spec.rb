# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Encryption::DbKeyBaseRotation::Table, feature_category: :cell do
  let(:hook_columns) do
    [
      Gitlab::Encryption::DbKeyBaseRotation::AttrEncryptedColumn.new(WebHook, :url),
      Gitlab::Encryption::DbKeyBaseRotation::AttrEncryptedColumn.new(WebHook, :token)
    ]
  end

  describe '#columns' do
    it 'lists every stored column' do
      table = described_class.new('web_hooks', WebHook, hook_columns)

      expect(table.columns).to eq(%w[encrypted_url encrypted_url_iv encrypted_token encrypted_token_iv])
    end
  end

  describe '#key_columns' do
    it 'is the primary key' do
      expect(described_class.new('web_hooks', WebHook, hook_columns).key_columns).to eq(%w[id])
    end

    it 'adds the partition key of partitioned tables' do
      table = described_class.new('p_ci_builds', CommitStatus, [])

      expect(table.key_columns).to eq(%w[id partition_id])
    end

    it 'adds a partition key that is not partition_id' do
      expect(described_class.new('ci_runners', Ci::Runner, []).key_columns).to eq(%w[id runner_type])
    end

    it 'ignores a partition_id column outside the primary key' do
      expect(described_class.new('ci_job_variables', Ci::JobVariable, []).key_columns).to eq(%w[id])
    end
  end

  describe '#filter' do
    it "applies the model's filter" do
      table = described_class.new('p_ci_builds', CommitStatus, [])
      relation = table.scope
      filtered = CommitStatus.none

      expect(CommitStatus).to receive(:db_key_base_reencryption_filter).with(relation).and_return(filtered)

      expect(table.filter(relation)).to be(filtered)
    end

    it 'keeps every row of other tables' do
      table = described_class.new('web_hooks', WebHook, hook_columns)
      relation = table.scope

      expect(table.filter(relation)).to be(relation)
    end
  end
end
