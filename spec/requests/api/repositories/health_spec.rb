# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::Repositories, feature_category: :source_code_management do
  let_it_be(:user) { create(:user) }
  let!(:maintainer) { create(:project_member, :maintainer, user: user, project: project) }
  let(:guest) { create(:user).tap { |u| create(:project_member, :guest, user: u, project: project) } }
  let(:developer) { create(:user).tap { |u| create(:project_member, :developer, user: u, project: project) } }

  describe 'GET :id/repository/health' do
    let(:project) { create(:project, :repository, creator: user) }
    let(:params) { nil }

    subject(:request) do
      get(api("/projects/#{project.id}/repository/health", current_user), params: params)
    end

    shared_examples 'health' do
      it 'returns 404 on first invocation' do
        request

        expect(response).to have_gitlab_http_status(:not_found)
      end

      it 'returns 404 on subsequent invocations if a report has not been generated' do
        2.times do
          request
          expect(response).to have_gitlab_http_status(:not_found)
        end
      end

      describe 'when a new report is generated' do
        let(:params) { { generate: true } }

        it 'returns the health report' do
          t_start = Time.current
          request
          t_end = Time.current

          expect(response).to have_gitlab_http_status(:success)
          expect(json_response['size']).to be_present
          expect(json_response['objects']).to be_present
          expect(json_response['references']).to be_present
          expect(Time.parse(json_response['updated_at'])).to be_between(t_start, t_end)
        end

        it 'returns the health report even after a prior request without generate' do
          get(api("/projects/#{project.id}/repository/health", current_user))
          expect(response).to have_gitlab_http_status(:not_found)

          request

          expect(response).to have_gitlab_http_status(:success)
          expect(json_response['size']).to be_present
        end

        context 'when rate limited' do
          it 'returns api error' do
            allow(Gitlab::ApplicationRateLimiter).to receive(:throttled_request?).and_return(true)

            request

            expect(response).to have_gitlab_http_status(:too_many_requests)
          end
        end
      end
    end

    context 'when unauthenticated', 'and project is public' do
      it_behaves_like '403 response' do
        let(:project) { create(:project, :public, :repository) }
        let(:current_user) { nil }
      end
    end

    context 'when unauthenticated', 'and project is private' do
      it_behaves_like '404 response' do
        let(:current_user) { nil }
        let(:message) { '404 Project Not Found' }
      end
    end

    context 'when authenticated', 'as a maintainer' do
      it_behaves_like 'health' do
        let(:current_user) { user }
      end
    end

    context 'when authenticated', 'as a developer' do
      it_behaves_like 'health' do
        let(:current_user) { developer }
      end
    end

    context 'when authenticated', 'as a guest' do
      it_behaves_like '403 response' do
        let(:current_user) { guest }
      end
    end

    it_behaves_like 'authorizing granular token permissions', :read_repository_health do
      let(:params) { { generate: true } }
      let(:boundary_object) { project }
      let(:request) do
        get api("/projects/#{project.id}/repository/health", personal_access_token: pat), params: params
      end
    end
  end
end
