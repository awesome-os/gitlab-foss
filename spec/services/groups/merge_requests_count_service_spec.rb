# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Groups::MergeRequestsCountService, :use_clean_rails_memory_store_caching, feature_category: :groups_and_projects do
  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group, :public, reporters: user) }
  let_it_be(:project) { create(:project, namespace: group) }
  let_it_be(:merge_request) { create(:merge_request, source_project: project, target_project: project) }

  subject(:service) { described_class.new(group, user) }

  describe '#relation_for_count' do
    before do
      allow(MergeRequestsFinder).to receive(:new).and_call_original
    end

    it 'uses the MergeRequestsFinder to scope merge requests' do
      expect(MergeRequestsFinder)
        .to receive(:new)
        .with(user, group_id: group.id, state: 'opened', non_archived: true, include_subgroups: true)

      subject.count
    end
  end

  it_behaves_like 'a counter caching service with threshold'

  describe '#count' do
    it 'does not execute the query with a fast timeout' do
      expect(ApplicationRecord).not_to receive(:with_fast_read_statement_timeout)

      expect(service.count).to eq(1)
    end

    context 'when fast_timeout is enabled' do
      subject(:fast_service) { described_class.new(group, user, fast_timeout: true) }

      it 'executes the query with a fast timeout' do
        expect(ApplicationRecord).to receive(:with_fast_read_statement_timeout).and_call_original

        expect(fast_service.count).to eq(1)
      end
    end
  end
end
