# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::Repositories, feature_category: :source_code_management do
  let_it_be(:user) { create(:user) }
  let_it_be(:project, reload: true) { create(:project, :repository, creator: user) }
  let!(:maintainer) { create(:project_member, :maintainer, user: user, project: project) }
  let(:guest) { create(:user).tap { |u| create(:project_member, :guest, user: u, project: project) } }

  describe 'GET /projects/:id/repository/diverging_commits' do
    let(:route) { "/projects/#{project.id}/repository/diverging_commits" }

    shared_examples 'diverging commits' do
      it 'returns ahead and behind counts' do
        get api(route, current_user), params: { from: 'master', to: 'feature' }

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response['ahead']).to be_a(Integer)
        expect(json_response['behind']).to be_a(Integer)
      end

      it 'returns zeros for same ref' do
        get api(route, current_user), params: { from: 'master', to: 'master' }

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response['ahead']).to eq(0)
        expect(json_response['behind']).to eq(0)
      end

      it 'accepts max_count parameter' do
        get api(route, current_user), params: { from: 'master', to: 'feature', max_count: 10 }

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response['ahead']).to be_a(Integer)
        expect(json_response['behind']).to be_a(Integer)
      end

      it 'returns 400 when max_count is negative' do
        get api(route, current_user), params: { from: 'master', to: 'feature', max_count: -1 }

        expect(response).to have_gitlab_http_status(:bad_request)
        expect(json_response['error']).to include('max_count')
      end

      it 'returns 400 when the from ref does not exist' do
        get api(route, current_user), params: { from: 'unknown_ref', to: 'master' }

        expect(response).to have_gitlab_http_status(:bad_request)
        expect(json_response['message']).to eq('Invalid from or to ref')
      end

      it 'returns 400 when the to ref does not exist' do
        get api(route, current_user), params: { from: 'master', to: 'unknown_ref' }

        expect(response).to have_gitlab_http_status(:bad_request)
        expect(json_response['message']).to eq('Invalid from or to ref')
      end

      it 'returns 400 when both refs do not exist' do
        get api(route, current_user), params: { from: 'unknown_ref', to: 'also_unknown' }

        expect(response).to have_gitlab_http_status(:bad_request)
        expect(json_response['message']).to eq('Invalid from or to ref')
      end

      it 'returns 400 when params are missing' do
        get api(route, current_user)

        expect(response).to have_gitlab_http_status(:bad_request)
      end

      it 'returns 400 when a ref exceeds the length limit' do
        get api(route, current_user), params: { from: 'a' * 256, to: 'master' }

        expect(response).to have_gitlab_http_status(:bad_request)
        expect(json_response['error']).to include('from')
      end

      it 'presents the counts through the entity' do
        get api(route, current_user), params: { from: 'master', to: 'feature' }

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response.keys).to match_array(%w[ahead behind])
      end

      it 'rate limits the user when thresholds are hit' do
        allow(::Gitlab::ApplicationRateLimiter).to receive(:throttled?).and_return(true)

        get api(route, current_user), params: { from: 'master', to: 'feature' }

        expect(response).to have_gitlab_http_status(:too_many_requests)
      end

      context 'when repository is disabled' do
        include_context 'disabled repository'

        it_behaves_like '403 response' do
          let(:request) { get api(route, current_user), params: { from: 'master', to: 'feature' } }
        end
      end
    end

    context 'when the repository_diverging_commits_api feature flag is disabled' do
      before do
        stub_feature_flags(repository_diverging_commits_api: false)
      end

      it_behaves_like '404 response' do
        let(:request) { get api(route, user), params: { from: 'master', to: 'feature' } }
      end
    end

    context 'when authenticated', 'as a developer' do
      it_behaves_like 'diverging commits' do
        let(:current_user) { user }
      end
    end

    context 'when authenticated', 'as a guest' do
      it_behaves_like '403 response' do
        let(:request) { get api(route, guest), params: { from: 'master', to: 'feature' } }
      end
    end

    context 'when unauthenticated', 'and project is private' do
      it_behaves_like '404 response' do
        let(:request) { get api(route), params: { from: 'master', to: 'feature' } }
        let(:message) { '404 Project Not Found' }
      end
    end

    context 'when unauthenticated', 'and project is public' do
      let_it_be(:public_project) { create(:project, :public, :repository) }
      let(:route) { "/projects/#{public_project.id}/repository/diverging_commits" }

      it_behaves_like '401 response' do
        let(:request) { get api(route), params: { from: 'master', to: 'feature' } }
      end

      it 'returns 401 before validating parameters' do
        get api(route)

        expect(response).to have_gitlab_http_status(:unauthorized)
      end
    end

    it_behaves_like 'authorizing granular token permissions', :read_commit do
      let(:boundary_object) { project }
      let(:request) do
        get api(route, personal_access_token: pat), params: { from: 'master', to: 'feature' }
      end
    end
  end
end
