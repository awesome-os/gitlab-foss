# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::Repositories, feature_category: :source_code_management do
  let_it_be(:user) { create(:user) }
  let_it_be(:project, reload: true) { create(:project, :repository, creator: user) }
  let!(:maintainer) { create(:project_member, :maintainer, user: user, project: project) }
  let(:guest) { create(:user).tap { |u| create(:project_member, :guest, user: u, project: project) } }

  describe 'GET /projects/:id/repository/changed_paths' do
    let(:route) { "/projects/#{project.id}/repository/changed_paths" }

    before do
      allow(::Gitlab::ApplicationRateLimiter).to receive(:throttled?).and_return(false)
    end

    shared_examples 'changed paths' do
      it 'returns changed files between two refs with pagination headers' do
        get api(route, current_user), params: { from: 'master', to: 'feature' }

        expect(response).to have_gitlab_http_status(:ok)
        expect(response).to include_pagination_headers
        expect(json_response).to be_an(Array)
        expect(json_response).not_to be_empty

        valid_statuses = %w[ADDED MODIFIED DELETED RENAMED TYPE_CHANGED COPIED]

        json_response.each do |entry|
          expect(entry['status']).to be_in(valid_statuses)
          expect(entry['path']).to be_a(String).and be_present
          expect(entry['old_path']).to be_a(String)
          expect(entry['old_mode']).to be_a(String)
          expect(entry['new_mode']).to be_a(String)
        end
      end

      context 'when the repository_changed_paths_api feature flag is disabled' do
        before do
          stub_feature_flags(repository_changed_paths_api: false)
        end

        it 'returns 404' do
          get api(route, current_user), params: { from: 'master', to: 'feature' }

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end

      it 'returns 404 when from ref does not exist' do
        get api(route, current_user), params: { from: 'unknown_ref', to: 'master' }

        expect(response).to have_gitlab_http_status(:not_found)
      end

      it 'returns 404 when to ref does not exist' do
        get api(route, current_user), params: { from: 'master', to: 'unknown_ref' }

        expect(response).to have_gitlab_http_status(:not_found)
      end

      it 'returns an empty array for identical refs' do
        get api(route, current_user), params: { from: 'master', to: 'master' }

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response).to be_an(Array)
        expect(json_response).to be_empty
      end

      it 'accepts find_renames parameter' do
        get api(route, current_user), params: { from: 'master', to: 'feature', find_renames: true }

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response).to be_an(Array)
      end

      it 'returns 400 when params are missing' do
        get api(route, current_user)

        expect(response).to have_gitlab_http_status(:bad_request)
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

    context 'when authenticated', 'as a developer' do
      it_behaves_like 'changed paths' do
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
      let(:route) { "/projects/#{public_project.id}/repository/changed_paths" }

      it_behaves_like '401 response' do
        let(:request) { get api(route), params: { from: 'master', to: 'feature' } }
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
