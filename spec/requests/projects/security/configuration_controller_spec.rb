# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Projects::Security::ConfigurationController, feature_category: :security_testing_configuration do
  let(:project) { create(:project, :public) }
  let(:user) { create(:user) }

  before do
    allow_next_instance_of(described_class) do |controller|
      allow(controller).to receive(:ensure_security_and_compliance_enabled!)
    end

    sign_in(user)
  end

  describe 'GET /:namespace/:project/-/security/configuration' do
    context 'when user has guest access' do
      before do
        project.add_guest(user)
      end

      it 'denies access' do
        get project_security_configuration_path(project)

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end

    context 'when user has developer access' do
      before do
        project.add_developer(user)
      end

      it 'grants access' do
        get project_security_configuration_path(project)

        expect(response).to have_gitlab_http_status(:ok)
        expect(response.body).to have_css('#js-security-configuration')
      end

      it 'responds with configuration data json' do
        get project_security_configuration_path(project, format: :json)

        features = json_response['features']
        sast_feature = features.find { |feature| feature['type'] == 'sast' }
        dast_feature = features.find { |feature| feature['type'] == 'dast' }

        expect(response).to have_gitlab_http_status(:ok)
        expect(sast_feature['available']).to be_truthy
        expect(dast_feature['available']).to be_falsey
      end
    end
  end
end
