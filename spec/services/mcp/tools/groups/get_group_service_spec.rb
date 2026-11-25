# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mcp::Tools::Groups::GetGroupService, feature_category: :mcp_server do
  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group, :public) }

  let(:service) { described_class.new(name: 'get_group') }

  before do
    service.set_cred(current_user: user)
  end

  describe 'input schema' do
    it 'locks the full input schema for version 0.1.0' do
      expect(described_class.version_metadata('0.1.0')[:input_schema]).to eq({
        type: 'object',
        required: [],
        properties: {
          url: {
            type: 'string',
            description: 'GitLab URL of the group.'
          },
          group_id: {
            type: 'string',
            description: 'Group ID or full path. Provide exactly one of url or group_id.'
          }
        }
      })
    end
  end

  describe '#execute' do
    let(:request) { Grape::Request.new(Rack::MockRequest.env_for('/api/v4/mcp')) }
    let(:arguments) { { group_id: group.id.to_s } }

    subject(:result) { service.execute(request: request, params: { arguments: arguments }) }

    it 'returns the group metadata', :aggregate_failures do
      expect(result[:isError]).to be(false)
      expect(result[:structuredContent]['id']).to eq(group.id)
      expect(result[:structuredContent]['fullPath']).to eq(group.full_path)
    end

    context 'with a group URL' do
      let(:arguments) { { url: group.web_url } }

      it 'returns the group metadata' do
        expect(result[:structuredContent]['id']).to eq(group.id)
      end
    end

    context 'without an identifier' do
      let(:arguments) { {} }

      it 'returns a bad-request error', :aggregate_failures do
        expect(result[:isError]).to be(true)
        expect(Mcp::Tools::Base::Response.error_reason(result)).to eq(:bad_request)
      end
    end

    context 'with both identifiers' do
      let(:arguments) { { url: group.web_url, group_id: group.id.to_s } }

      it 'returns a bad-request error' do
        expect(Mcp::Tools::Base::Response.error_reason(result)).to eq(:bad_request)
      end
    end

    context 'with an unknown argument' do
      let(:arguments) { { group_id: group.id.to_s, search: 'group' } }

      it 'rejects the unknown argument', :aggregate_failures do
        expect(result[:isError]).to be(true)
        expect(Mcp::Tools::Base::Response.error_reason(result)).to eq(:bad_request)
      end
    end

    context 'with a missing group' do
      let(:arguments) { { group_id: non_existing_record_id.to_s } }

      it 'returns a not-found error' do
        expect(Mcp::Tools::Base::Response.error_reason(result)).to eq(:not_found)
      end
    end

    context 'with an inaccessible group' do
      let_it_be(:private_group) { create(:group, :private) }

      let(:arguments) { { group_id: private_group.id.to_s } }

      it 'returns an unauthorized error' do
        expect(Mcp::Tools::Base::Response.error_reason(result)).to eq(:unauthorized)
      end
    end

    context 'without a current user' do
      before do
        service.set_cred(current_user: nil)
      end

      it 'returns an unauthorized error' do
        expect(Mcp::Tools::Base::Response.error_reason(result)).to eq(:unauthorized)
      end
    end
  end
end
