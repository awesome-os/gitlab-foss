# frozen_string_literal: true

module Organizations
  # Published when an organization transitions from `unconfirmed` to `confirmed`.
  #
  # TODO: Remove once Organizations::ConfirmedCloudEvent has replaced it and
  # in-flight legacy events have drained.
  # See https://gitlab.com/gitlab-org/gitlab/-/work_items/605304
  class ConfirmedEvent < Gitlab::EventStore::Event
    def schema
      {
        'type' => 'object',
        'required' => %w[organization_id],
        'properties' => {
          'organization_id' => { 'type' => 'integer' }
        }
      }
    end
  end
end
