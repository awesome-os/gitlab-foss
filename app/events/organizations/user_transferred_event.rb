# frozen_string_literal: true

module Organizations
  # Published when users are transferred to a different organization.
  # Fired once per batch of users, after the transfer has been committed.
  #
  # The transfer moves users with `update_all`, so subscribers cannot discover which
  # users moved after the fact - the ids have to travel with the event.
  class UserTransferredEvent < Gitlab::EventStore::CloudEvent
    event_category :organizations
    event_type :user_transferred

    def self.build(user_ids:, old_organization:, new_organization:)
      build_cloud_event(
        source: "organizations/#{old_organization.id}",
        subject: "organizations/#{new_organization.id}",
        organization: new_organization,
        event_data: {
          user_ids: user_ids,
          old_organization_id: old_organization.id,
          new_organization_id: new_organization.id
        }
      )
    end

    def data_schema
      {
        'type' => 'object',
        'required' => %w[user_ids old_organization_id new_organization_id],
        'properties' => {
          'user_ids' => { 'type' => 'array', 'items' => { 'type' => 'integer' } },
          'old_organization_id' => { 'type' => 'integer' },
          'new_organization_id' => { 'type' => 'integer' }
        },
        'additionalProperties' => false
      }
    end
  end
end
