# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::Repositories, feature_category: :source_code_management do
  let_it_be(:user) { create(:user) }
  let_it_be(:project, reload: true) { create(:project, :repository, creator: user) }
  let!(:maintainer) { create(:project_member, :maintainer, user: user, project: project) }
  let(:guest) { create(:user).tap { |u| create(:project_member, :guest, user: u, project: project) } }

  describe 'GET /projects/:id/repository/diff_stats' do
    let(:route) { "/projects/#{project.id}/repository/diff_stats" }

    before do
      allow(::Gitlab::ApplicationRateLimiter).to receive(:throttled?).and_return(false)
    end

    shared_examples 'diff stats' do
      it 'returns diff statistics between two refs with pagination headers' do
        get api(route, current_user), params: { from: 'master', to: 'feature' }

        expect(response).to have_gitlab_http_status(:ok)
        expect(response).to include_pagination_headers
        expect(json_response).to be_an(Array)

        first_stat = json_response.first
        expect(first_stat['path']).to be_present
        expect(first_stat['additions']).to be_a(Integer)
        expect(first_stat['deletions']).to be_a(Integer)
      end

      it 'returns empty array for same refs' do
        get api(route, current_user), params: { from: 'master', to: 'master' }

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response).to be_an(Array)
        expect(json_response).to be_empty
      end

      it 'returns 404 when from ref does not exist' do
        get api(route, current_user), params: { from: 'unknown_ref', to: 'master' }

        expect(response).to have_gitlab_http_status(:not_found)
        expect(json_response['message']).to eq('404 From ref Not Found')
      end

      it 'returns 404 when to ref does not exist' do
        get api(route, current_user), params: { from: 'master', to: 'unknown_ref' }

        expect(response).to have_gitlab_http_status(:not_found)
        expect(json_response['message']).to eq('404 To ref Not Found')
      end

      it 'returns 404 when both refs do not exist' do
        get api(route, current_user), params: { from: 'unknown_ref', to: 'another_unknown_ref' }

        expect(response).to have_gitlab_http_status(:not_found)
        expect(json_response['message']).to eq('404 From ref and To ref Not Found')
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

    context 'when the repository_diff_stats_api feature flag is disabled' do
      before do
        stub_feature_flags(repository_diff_stats_api: false)
      end

      it_behaves_like '404 response' do
        let(:request) { get api(route, user), params: { from: 'master', to: 'feature' } }
      end
    end

    context 'when authenticated', 'as a developer' do
      it_behaves_like 'diff stats' do
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
      let(:route) { "/projects/#{public_project.id}/repository/diff_stats" }

      it_behaves_like '401 response' do
        let(:request) { get api(route), params: { from: 'master', to: 'feature' } }
      end

      it 'returns 401 before validating parameters' do
        get api(route)

        expect(response).to have_gitlab_http_status(:unauthorized)
      end
    end

    it_behaves_like 'authorizing granular token permissions', :read_repository_comparison do
      let(:boundary_object) { project }
      let(:request) do
        get api(route, personal_access_token: pat), params: { from: 'master', to: 'feature' }
      end
    end
  end
end
