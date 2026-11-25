# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Projects::Analytics::CycleAnalytics::ValueStreamsController,
  feature_category: :value_stream_management do
  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group) }
  let_it_be_with_reload(:project) { create(:project, group: group) }

  let(:path) { namespace_project_analytics_cycle_analytics_value_streams_path(group, project) }

  before do
    sign_in(user)
  end

  describe 'GET /:namespace/:project/-/analytics/value_stream_analytics/value_streams' do
    context 'when user is member of the project' do
      before_all do
        project.add_developer(user)
      end

      it 'succeeds' do
        get path

        expect(response).to have_gitlab_http_status(:ok)
      end

      it 'exposes the default value stream' do
        get path

        expect(json_response.first['name']).to eq('default')
      end

      # testing the authorize method within ValueStreamActions
      context 'when issues and merge requests are disabled' do
        it 'renders 404' do
          project.project_feature.update!(
            issues_access_level: ProjectFeature::DISABLED,
            merge_requests_access_level: ProjectFeature::DISABLED
          )

          get path

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end
    end

    context 'when user is not member of the project' do
      it 'renders 404' do
        get path

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end
  end
end
