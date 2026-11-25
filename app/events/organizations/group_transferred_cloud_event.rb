# frozen_string_literal: true

module Organizations
  # Published when a root group is transferred to a different organization.
  # Fired once for the transferred group only - NOT for its descendants.
  # Subscribers are responsible for traversing descendants if needed.
  class GroupTransferredCloudEvent < Gitlab::EventStore::CloudEvent
    event_category :organizations
    event_type :group_transferred

    def self.build(group_id:, old_organization_id:, new_organization:, current_user: nil)
      build_cloud_event(
        source: "groups/#{group_id}",
        subject: "groups/#{group_id}",
        current_user: current_user,
        organization: new_organization,
        event_data: {
          group_id: group_id,
          old_organization_id: old_organization_id,
          new_organization_id: new_organization.id
        }
      )
    end

    def data_schema
      {
        'type' => 'object',
        'required' => %w[group_id old_organization_id new_organization_id],
        'properties' => {
          'group_id' => { 'type' => 'integer' },
          'old_organization_id' => { 'type' => 'integer' },
          'new_organization_id' => { 'type' => 'integer' }
        },
        'additionalProperties' => false
      }
    end
  end
end
