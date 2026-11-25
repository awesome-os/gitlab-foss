# frozen_string_literal: true

require 'spec_helper'
require_relative '../../../app/events/merge_requests/pushed_cloud_event'
require_relative '../../support/shared_examples/events/cloud_event_with_schema_shared_examples'
require_relative '../../support/shared_examples/events/merge_request_base_cloud_event_shared_examples'

RSpec.describe MergeRequests::PushedCloudEvent, feature_category: :code_review_workflow do
  let_it_be(:user) { create(:user) }
  let_it_be(:merge_request) { create(:merge_request) }

  let(:oldrev) { 'a' * 40 }
  let(:newrev) { 'b' * 40 }

  describe '.build' do
    let(:event) do
      described_class.build(merge_request: merge_request, current_user: user, oldrev: oldrev, newrev: newrev)
    end

    it_behaves_like 'a merge request base cloud event'

    it 'sets event_type to :pushed' do
      expect(event.event_type).to eq(:pushed)
    end

    it 'includes the revisions of the push', :aggregate_failures do
      expect(event.event_data[:oldrev]).to eq(oldrev)
      expect(event.event_data[:newrev]).to eq(newrev)
    end
  end

  it_behaves_like 'a cloud event with schema',
    valid_data: {
      merge_request_id: 1,
      merge_request_iid: 10,
      project_id: 100,
      oldrev: 'a' * 40,
      newrev: 'b' * 40
    },
    missing_required: %i[merge_request_id merge_request_iid project_id newrev],
    invalid_types: {
      merge_request_id: 'not_an_integer',
      merge_request_iid: 'not_an_integer',
      project_id: 'not_an_integer',
      oldrev: 123,
      newrev: 123
    }
end
