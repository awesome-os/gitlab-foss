# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::Repositories, feature_category: :source_code_management do
  let_it_be(:user) { create(:user) }
  let_it_be(:project, reload: true) { create(:project, :repository, creator: user) }
  let!(:maintainer) { create(:project_member, :maintainer, user: user, project: project) }
  let(:guest) { create(:user).tap { |u| create(:project_member, :guest, user: u, project: project) } }

  describe 'GET /projects/:id/repository/contributors' do
    let(:route) { "/projects/#{project.id}/repository/contributors" }

    shared_examples_for 'repository contributors' do
      it 'returns valid data' do
        get api(route, current_user)

        expect(response).to have_gitlab_http_status(:ok)
        expect(response).to include_pagination_headers
        expect(json_response).to be_an Array

        first_contributor = json_response.first
        expect(first_contributor['email']).to eq('tiagonbotelho@hotmail.com')
        expect(first_contributor['name']).to eq('tiagonbotelho')
        expect(first_contributor['commits']).to eq(1)
        expect(first_contributor['additions']).to eq(0)
        expect(first_contributor['deletions']).to eq(0)
      end

      context 'using ref' do
        new_branch_name = 'feature-test'
        let(:user) { create(:user, name: "johndoe", email: "johndoe@example.com") }

        before do
          project.repository.add_branch(user, new_branch_name, 'master')
          project.repository.commit_files(
            user,
            branch_name: new_branch_name,
            message: 'Message',
            actions: [{ action: :create, file_path: 'a/new.file', content: 'This is a new file' }]
          )
        end

        it 'returns valid data for the ref' do
          get api(route, current_user), params: { ref: new_branch_name }

          expect(response).to have_gitlab_http_status(:ok)
          expect(response).to include_pagination_headers
          expect(json_response).to be_an Array

          first_contributor = json_response.first
          expect(first_contributor['email']).to eq('johndoe@example.com')
          expect(first_contributor['name']).to eq('johndoe')
          expect(first_contributor['commits']).to eq(1)
          expect(first_contributor['additions']).to eq(0)
          expect(first_contributor['deletions']).to eq(0)
        end
      end

      context 'using sorting' do
        context 'by commits desc' do
          it 'returns the repository contributors sorted by commits desc' do
            get api(route, current_user), params: { order_by: 'commits', sort: 'desc' }

            expect(response).to have_gitlab_http_status(:ok)
            expect(response).to match_response_schema('contributors')
            expect(json_response.first['commits']).to be > json_response.last['commits']
          end
        end

        context 'by name desc' do
          it 'returns the repository contributors sorted by name asc case insensitive' do
            get api(route, current_user), params: { order_by: 'name', sort: 'asc' }

            expect(response).to have_gitlab_http_status(:ok)
            expect(response).to match_response_schema('contributors')
            expect(json_response.first['name'].downcase).to be < json_response.last['name'].downcase
          end
        end
      end
    end

    context 'when unauthenticated', 'and project is public' do
      it_behaves_like 'repository contributors' do
        let(:project) { create(:project, :public, :repository) }
        let(:current_user) { nil }
      end
    end

    context 'when unauthenticated', 'and project is private' do
      it_behaves_like '404 response' do
        let(:request) { get api(route) }
        let(:message) { '404 Project Not Found' }
      end
    end

    context 'when authenticated', 'as a developer' do
      it_behaves_like 'repository contributors' do
        let(:project) { create(:project, :repository, creator: user) }
        let(:current_user) { user }
      end
    end

    context 'when authenticated', 'as a guest' do
      it_behaves_like '403 response' do
        let(:request) { get api(route, guest) }
      end
    end

    # Regression: https://gitlab.com/gitlab-org/gitlab-foss/issues/45363
    describe 'Links header contains working URLs when no `order_by` nor `sort` is given' do
      let(:project) { create(:project, :public, :repository) }
      let(:current_user) { nil }

      it 'returns `Link` header that includes URLs with default value for `order_by` & `sort`' do
        get api(route, current_user)

        first_link_url = response.headers['Link'].split(';').first

        expect(first_link_url).to include('order_by=commits')
        expect(first_link_url).to include('sort=asc')
      end
    end

    it_behaves_like 'authorizing granular token permissions', :read_repository_contributor do
      let(:boundary_object) { project }
      let(:request) do
        get api(route, personal_access_token: pat)
      end
    end
  end
end
