# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RapidDiffs::DiffVersionEntity, feature_category: :code_review_workflow do
  include Gitlab::Routing.url_helpers
  include MergeRequestsHelper

  let_it_be(:merge_request) { build_stubbed(:merge_request, :skip_diff_creation) }
  let_it_be(:diff_1) { build_stubbed(:merge_request_diff, merge_request: merge_request) }
  let_it_be(:diff_2) { build_stubbed(:merge_request_diff, merge_request: merge_request, head_commit_sha: 'abc123def') }

  let(:options) do
    {
      merge_request: merge_request,
      version_indexes: { diff_2.id => 2, diff_1.id => 1 }
    }
  end

  let(:merge_request_diff) { diff_2 }
  let(:entity) { described_class.new(merge_request_diff, options) }

  subject(:serialized) { entity.as_json }

  describe 'serialization' do
    it 'inherits attributes from DiffVersionEntity' do
      expect(serialized).to include(
        :id,
        :version_index,
        :is_merge_head,
        :latest,
        :short_commit_sha,
        :commits_count,
        :created_at
      )
    end
  end

  describe 'version_index' do
    it 'returns the index for this version' do
      expect(serialized[:version_index]).to eq(2)
    end

    context 'when diff has no index' do
      let(:merge_request_diff) { build_stubbed(:merge_request_diff, merge_request: merge_request) }

      it 'returns nil' do
        expect(serialized[:version_index]).to be_nil
      end
    end
  end

  describe 'latest' do
    before do
      allow(merge_request).to receive(:latest_merge_request_diff_id).and_return(diff_2.id)
    end

    it 'returns true for the latest diff' do
      expect(serialized[:latest]).to be(true)
    end

    it 'does not read the diff through its merge_request' do
      expect(merge_request_diff).not_to receive(:merge_request)

      serialized
    end

    context 'when the diff is an older version' do
      let(:merge_request_diff) { diff_1 }

      it 'returns false' do
        expect(serialized[:latest]).to be(false)
      end
    end
  end

  describe '#short_commit_sha' do
    it 'returns short sha' do
      expect(serialized[:short_commit_sha]).to eq('abc123de')
    end

    it 'returns nil if head_commit_sha does not exist' do
      allow(merge_request_diff).to receive(:head_commit_sha).and_return(nil)

      expect(serialized[:short_commit_sha]).to be_nil
    end
  end
end
