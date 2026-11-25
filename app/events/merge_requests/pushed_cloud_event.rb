# frozen_string_literal: true

module MergeRequests
  class PushedCloudEvent < BaseCloudEvent
    event_type :pushed

    class << self
      # @param merge_request [MergeRequest] an open merge request whose source branch got the push
      # @param current_user [User] the pusher
      # @param oldrev [String] the source branch SHA before the push
      # @param newrev [String] the source branch SHA after the push
      # @return [MergeRequests::PushedCloudEvent]
      def build(merge_request:, current_user:, oldrev:, newrev:)
        build_for_merge_request(
          merge_request: merge_request,
          current_user: current_user,
          extra_event_data: { oldrev: oldrev, newrev: newrev }
        )
      end
    end

    private

    def additional_properties
      {
        'oldrev' => { 'type' => 'string' },
        'newrev' => { 'type' => 'string' }
      }
    end

    def additional_required
      %w[newrev]
    end
  end
end
