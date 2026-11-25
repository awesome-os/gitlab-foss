# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Organizations::GroupTransferredCloudEvent, feature_category: :organization do
  let(:user) { build_stubbed(:user) }
  let(:new_organization) { build_stubbed(:organization) }
  let(:group_id) { 42 }
  let(:old_organization_id) { 7 }

  def build_event(current_user: nil)
    described_class.build(
      group_id: group_id,
      old_organization_id: old_organization_id,
      new_organization: new_organization,
      current_user: current_user
    )
  end

  describe '.build' do
    it 'builds a valid cloud event for the transferred group', :aggregate_failures do
      event = build_event

      expect(event.event_category).to eq(:organizations)
      expect(event.event_type).to eq(:group_transferred)
      expect(event.data[:type]).to eq('com.gitlab.organizations.group_transferred')
      expect(event.data[:source]).to eq("groups/#{group_id}")
      expect(event.data[:subject]).to eq("groups/#{group_id}")
      expect(event.data[:gitlab_organization_id]).to eq(new_organization.id)
      expect(event.data).not_to have_key(:gitlab_user_id)
      expect(event.event_data).to eq(
        group_id: group_id,
        old_organization_id: old_organization_id,
        new_organization_id: new_organization.id
      )
    end

    it 'sets the user envelope attributes when a current_user is given', :aggregate_failures do
      event = build_event(current_user: user)

      expect(event.data[:gitlab_user_id]).to eq(user.id)
      expect(event.data[:gitlab_user_username]).to eq(user.username)
    end
  end

  it_behaves_like 'a cloud event with schema',
    valid_data: { group_id: 1, old_organization_id: 2, new_organization_id: 3 },
    missing_required: %i[group_id old_organization_id new_organization_id],
    invalid_types: {
      group_id: 'not_an_integer',
      old_organization_id: 'not_an_integer',
      new_organization_id: 'not_an_integer'
    }

  describe '#data_schema' do
    it 'rejects unexpected properties' do
      event = build_event
      invalid_data = event.data.merge(data: event.event_data.merge(unexpected: 'data'))

      expect { described_class.new(data: invalid_data) }
        .to raise_error(Gitlab::EventStore::InvalidEvent, /does not match/)
    end
  end
end
