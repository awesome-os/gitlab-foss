# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'doorkeeper/device_authorization_grant/authorize', feature_category: :system_access do
  let_it_be(:user) { build_stubbed(:user) }

  before do
    assign(:application, application)
    assign(:scopes, 'mcp')
    allow(view).to receive(:current_user).and_return(user)
  end

  describe 'trust warning on GitLab.com', :saas do
    context 'when the application has no owner' do
      let(:application) { build_stubbed(:oauth_application, owner: nil) }

      it 'does not warn' do
        render

        expect(rendered).not_to include('Make sure you trust')
      end
    end

    context 'when the application was registered from a client metadata document' do
      let(:application) do
        build_stubbed(:oauth_application, owner: nil, cimd_url: 'https://client.example.com/oauth/client.json')
      end

      it 'warns' do
        render

        expect(rendered).to include('Make sure you trust')
      end

      it 'says an anonymous service added the application' do
        render

        expect(rendered).to include('An anonymous service added this OAuth application')
      end
    end
  end
end
