# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Projects::FeatureFlagsClientsController, feature_category: :feature_flags do
  let_it_be(:project) { create(:project) }
  let_it_be(:maintainer) { create(:user, maintainer_of: project) }
  let_it_be(:developer) { create(:user, developer_of: project) }

  describe 'POST /:namespace/:project/-/feature_flags_client/reset_token' do
    subject(:reset_token) do
      post reset_token_project_feature_flags_client_path(project, format: :json)
    end

    context 'when user is a project maintainer' do
      before do
        sign_in(maintainer)
      end

      context 'when feature flags client exists' do
        it 'regenerates feature flags client token' do
          project.create_operations_feature_flags_client!
          expect { reset_token }.to change { project.reload.feature_flags_client_token }

          expect(json_response['token']).to eq(project.feature_flags_client_token)
        end
      end

      context 'when feature flags client does not exist' do
        it 'returns 404' do
          reset_token

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end
    end

    context 'when user is not a project maintainer' do
      before do
        sign_in(developer)
      end

      it 'returns 404 and does not reset the token' do
        client = create(:operations_feature_flags_client, project: project)

        expect { reset_token }.not_to change { client.reload.token }

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end
  end
end
