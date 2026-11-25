# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mcp::Tools::Groups::GetGroupTool, feature_category: :mcp_server do
  let_it_be(:user) { create(:user) }
  let_it_be(:parent) { create(:group, :public) }
  let_it_be(:group) { create(:group, :public, parent: parent) }

  let(:params) { { group_id: group.id.to_s } }
  let(:tool) { described_class.new(current_user: user, params: params, access_token: nil) }

  describe '#build_variables' do
    it 'resolves the group from its numeric ID' do
      expect(tool.build_variables).to eq({ fullPath: group.full_path })
    end

    context 'with a nested full path' do
      let(:params) { { group_id: group.full_path } }

      it 'resolves the group from the path' do
        expect(tool.build_variables).to eq({ fullPath: group.full_path })
      end
    end

    context 'with a group URL' do
      let(:params) { { url: group.web_url } }

      it 'resolves the group from the URL' do
        expect(tool.build_variables).to eq({ fullPath: group.full_path })
      end
    end

    context 'with an explicit groups URL' do
      let(:params) { { url: "#{Gitlab.config.gitlab.url}/groups/#{group.full_path}" } }

      it 'resolves the group from the URL' do
        expect(tool.build_variables).to eq({ fullPath: group.full_path })
      end
    end

    context 'with a bare top-level group URL' do
      let(:params) { { url: "#{Gitlab.config.gitlab.url}/#{parent.full_path}" } }

      it 'resolves the group from the URL' do
        expect(tool.build_variables).to eq({ fullPath: parent.full_path })
      end
    end

    context 'when no identifier is provided' do
      let(:params) { {} }

      it 'rejects the arguments' do
        expect { tool.build_variables }.to raise_error(ArgumentError, 'Provide exactly one of: url or group_id')
      end
    end

    context 'when both identifiers are provided' do
      let(:params) { { url: group.web_url, group_id: group.id.to_s } }

      it 'rejects the arguments' do
        expect { tool.build_variables }.to raise_error(ArgumentError, 'Provide exactly one of: url or group_id')
      end
    end
  end

  describe '#execute' do
    it 'returns group metadata with numeric IDs', :aggregate_failures do
      result = tool.execute

      expect(result[:isError]).to be(false)
      expect(result[:structuredContent]).to eq({
        'id' => group.id,
        'fullPath' => group.full_path,
        'name' => group.name,
        'visibility' => 'public',
        'webUrl' => group.web_url,
        'parent' => { 'id' => parent.id }
      })
      expect(Gitlab::Json::SafeParser.parse(result[:content].first[:text])).to eq(result[:structuredContent])
    end

    context 'with a top-level group' do
      let(:params) { { group_id: parent.id.to_s } }

      it 'returns a null parent', :aggregate_failures do
        result = tool.execute

        expect(result[:isError]).to be(false)
        expect(result[:structuredContent]['parent']).to be_nil
      end
    end

    context 'with a private group' do
      let_it_be(:private_group) { create(:group, :private) }

      let(:params) { { group_id: private_group.id.to_s } }

      it 'raises a forbidden error' do
        expect { tool.execute }.to raise_error(Mcp::Tools::Concerns::ResourceFinder::ResourceForbiddenError)
      end

      context 'when the caller is a member' do
        before_all do
          private_group.add_guest(user)
        end

        it 'returns the private group metadata' do
          expect(tool.execute[:structuredContent]['visibility']).to eq('private')
        end
      end
    end

    context 'when the group does not exist' do
      let(:params) { { group_id: non_existing_record_id.to_s } }

      it 'raises a not-found error' do
        expect { tool.execute }.to raise_error(Mcp::Tools::Concerns::ResourceFinder::ResourceNotFoundError)
      end
    end

    context 'when GraphQL returns errors' do
      before do
        allow(GitlabSchema).to receive(:execute).and_return({ 'errors' => [{ 'message' => 'Boom' }] })
      end

      it 'surfaces the error message', :aggregate_failures do
        result = tool.execute

        expect(result[:isError]).to be(true)
        expect(result[:content].first[:text]).to include('Boom')
      end
    end

    context 'when GraphQL returns no group' do
      before do
        allow(GitlabSchema).to receive(:execute).and_return({ 'data' => { 'group' => nil } })
      end

      it 'returns a group-not-found error', :aggregate_failures do
        result = tool.execute

        expect(result[:isError]).to be(true)
        expect(result[:content].first[:text]).to include('Group not found')
        expect(Mcp::Tools::Base::Response.error_reason(result)).to eq(:not_found)
      end
    end
  end
end
