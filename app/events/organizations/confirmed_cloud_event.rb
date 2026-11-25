# frozen_string_literal: true

module Organizations
  # Published when an organization transitions from `unconfirmed` to `confirmed`.
  class ConfirmedCloudEvent < Gitlab::EventStore::CloudEvent
    event_category :organizations
    event_type :confirmed

    def self.build(organization:, current_user: nil)
      build_cloud_event(
        source: "organizations/#{organization.id}",
        subject: "organizations/#{organization.id}",
        current_user: current_user,
        organization: organization,
        event_data: { organization_id: organization.id }
      )
    end

    def data_schema
      {
        'type' => 'object',
        'required' => %w[organization_id],
        'properties' => {
          'organization_id' => { 'type' => 'integer' }
        },
        'additionalProperties' => false
      }
    end
  end
end
