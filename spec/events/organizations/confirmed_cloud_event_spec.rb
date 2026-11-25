# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Organizations::ConfirmedCloudEvent, feature_category: :organization do
  let(:organization) { build_stubbed(:organization) }

  describe '.build' do
    it 'builds a valid cloud event for the organization', :aggregate_failures do
      event = described_class.build(organization: organization)

      expect(event.event_category).to eq(:organizations)
      expect(event.event_type).to eq(:confirmed)
      expect(event.data[:type]).to eq('com.gitlab.organizations.confirmed')
      expect(event.data[:source]).to eq("organizations/#{organization.id}")
      expect(event.data[:subject]).to eq("organizations/#{organization.id}")
      expect(event.data[:gitlab_organization_id]).to eq(organization.id)
      expect(event.event_data).to eq(organization_id: organization.id)
    end
  end

  describe '.build with a current_user' do
    let(:user) { build_stubbed(:user) }

    it 'sets the user envelope attributes', :aggregate_failures do
      event = described_class.build(organization: organization, current_user: user)

      expect(event.data[:gitlab_user_id]).to eq(user.id)
      expect(event.data[:gitlab_user_username]).to eq(user.username)
    end
  end

  it_behaves_like 'a cloud event with schema',
    valid_data: { organization_id: 1 },
    missing_required: %i[organization_id],
    invalid_types: { organization_id: 'not_an_integer' }

  describe '#data_schema' do
    it 'rejects unexpected properties' do
      event = described_class.build(organization: organization)
      invalid_data = event.data.merge(data: event.event_data.merge(unexpected: 'data'))

      expect { described_class.new(data: invalid_data) }
        .to raise_error(Gitlab::EventStore::InvalidEvent, /does not match/)
    end
  end
end
