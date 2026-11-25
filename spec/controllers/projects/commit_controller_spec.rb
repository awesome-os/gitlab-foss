# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Projects::CommitController, feature_category: :source_code_management do
  include ProjectForksHelper

  let_it_be(:project)  { create(:project, :repository) }
  let_it_be(:user)     { create(:user) }

  let(:commit) { project.commit("master") }
  let(:master_pickable_sha) { '7d3b0f7cff5f37573aea97cebfd5692ea1689924' }
  let(:master_pickable_commit) { project.commit(master_pickable_sha) }
  let(:pipeline) { create(:ci_pipeline, project: project, ref: project.default_branch, sha: commit.sha, status: :running) }
  let(:build) { create(:ci_build, pipeline: pipeline, status: :running) }

  before do
    sign_in(user)
    project.add_maintainer(user)
  end

  describe 'GET show' do
    render_views

    def go(extra_params = {})
      params = {
        namespace_id: project.namespace,
        project_id: project
      }

      get :show, params: params.merge(extra_params)
    end

    context 'with valid id' do
      it 'responds with 200' do
        go(id: commit.id)

        expect(response).to be_ok
      end

      context 'when a pipeline job is running' do
        before do
          build.run
        end

        it 'defines last pipeline information' do
          go(id: commit.id)

          expect(assigns(:last_pipeline)).to have_attributes(id: pipeline.id, status: 'running')
          expect(assigns(:last_pipeline_stages)).not_to be_empty
        end
      end
    end

    context 'with invalid id' do
      it 'responds with 404' do
        go(id: commit.id.reverse)

        expect(response).to be_not_found
        expect(assigns(:ref)).to be_nil
      end
    end

    it 'handles binary files' do
      go(id: TestEnv::BRANCH_SHA['binary-encoding'], format: 'html')

      expect(response).to be_successful
    end

    describe "as diff" do
      it "triggers workhorse to serve the request" do
        expect(Environments::EnvironmentsByDeploymentsFinder).not_to receive(:new)

        go(id: commit.id, format: :diff)

        expect(response.headers[Gitlab::Workhorse::SEND_DATA_HEADER]).to start_with("git-diff:")
      end
    end

    describe "as patch" do
      it "contains a git diff" do
        expect(Environments::EnvironmentsByDeploymentsFinder).not_to receive(:new)

        go(id: commit.id, format: :patch)

        expect(response.headers[Gitlab::Workhorse::SEND_DATA_HEADER]).to start_with("git-format-patch:")
      end
    end

    context 'commit that removes a submodule' do
      render_views

      let(:fork_project) { create(:forked_project_with_submodules, visibility_level: 20) }
      let(:commit) { fork_project.commit('remove-submodule') }

      it 'renders it' do
        get :show, params: { namespace_id: fork_project.namespace, project_id: fork_project, id: commit.id }

        expect(response).to be_successful
      end
    end

    context 'when gitaly is not available' do
      let(:commit_sha) { commit.id }

      before do
        allow_next_instance_of(Repository) do |repository|
          allow(repository).to receive(:commit_by).and_raise(GRPC::Unavailable)
        end
      end

      it 'returns 503 and sets gitaly_unavailable' do
        go(id: commit_sha)

        expect(response).to have_gitlab_http_status(:service_unavailable)
        expect(assigns(:gitaly_unavailable)).to be true
      end
    end
  end

  describe 'POST revert' do
    context 'when target branch is not provided' do
      it 'renders the 404 page' do
        post :revert, params: { namespace_id: project.namespace, project_id: project, id: commit.id }

        expect(response).not_to be_successful
        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context 'when the revert commit is missing' do
      it 'renders the 404 page' do
        post :revert, params: { namespace_id: project.namespace, project_id: project, start_branch: 'master', id: '1234567890' }

        expect(response).not_to be_successful
        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context 'when the revert was successful' do
      it 'redirects to the commits page' do
        post :revert, params: { namespace_id: project.namespace, project_id: project, start_branch: 'master', id: commit.id }

        expect(response).to redirect_to project_commits_path(project, 'master')
        expect(flash[:notice]).to eq('The commit has been successfully reverted.')
      end
    end

    context 'when the revert failed' do
      before do
        post :revert, params: { namespace_id: project.namespace, project_id: project, start_branch: 'master', id: commit.id }
      end

      it 'redirects to the commit page' do
        # Reverting a commit that has been already reverted.
        post :revert, params: { namespace_id: project.namespace, project_id: project, start_branch: 'master', id: commit.id }

        expect(response).to redirect_to project_commit_path(project, commit.id)
        expect(flash[:alert][:message]).to match('Commit revert failed:')
      end
    end

    context 'in the context of a merge_request' do
      let(:merge_request) { create(:merge_request, :merged, source_project: project) }
      let(:repository) { project.repository }

      before do
        merge_commit_id = repository.merge(user,
          merge_request.diff_head_sha,
          merge_request,
          'Test message')

        repository.commit(merge_commit_id)
        merge_request.update!(merge_commit_sha: merge_commit_id)
      end

      context 'when the revert was successful' do
        it 'redirects to the merge request page' do
          post :revert, params: { namespace_id: project.namespace, project_id: project, start_branch: 'master', id: merge_request.merge_commit_sha }

          expect(response).to redirect_to project_merge_request_path(project, merge_request)
          expect(flash[:notice]).to eq('The merge request has been successfully reverted.')
        end
      end

      context 'when the revert failed' do
        before do
          post :revert, params: { namespace_id: project.namespace, project_id: project, start_branch: 'master', id: merge_request.merge_commit_sha }
        end

        it 'redirects to the merge request page' do
          # Reverting a merge request that has been already reverted.
          post :revert, params: { namespace_id: project.namespace, project_id: project, start_branch: 'master', id: merge_request.merge_commit_sha }

          expect(response).to redirect_to project_merge_request_path(project, merge_request)
          expect(flash[:alert][:message]).to match('Merge request revert failed:')
        end
      end
    end
  end

  describe 'POST cherry_pick' do
    context 'when target branch is not provided' do
      it 'renders the 404 page' do
        post :cherry_pick, params: { namespace_id: project.namespace, project_id: project, id: master_pickable_commit.id }

        expect(response).not_to be_successful
        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context 'when the cherry-pick commit is missing' do
      it 'renders the 404 page' do
        post :cherry_pick, params: { namespace_id: project.namespace, project_id: project, start_branch: 'master', id: '1234567890' }

        expect(response).not_to be_successful
        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context 'when the cherry-pick was successful' do
      it 'redirects to the commits page' do
        post :cherry_pick, params: { namespace_id: project.namespace, project_id: project, start_branch: 'master', id: master_pickable_commit.id }

        expect(response).to redirect_to project_commits_path(project, 'master')
        expect(flash[:notice]).to eq('The commit has been successfully cherry-picked into master.')
      end
    end

    context 'when the cherry_pick failed' do
      before do
        post :cherry_pick, params: { namespace_id: project.namespace, project_id: project, start_branch: 'master', id: master_pickable_commit.id }
      end

      it 'redirects to the commit page' do
        # Cherry-picking a commit that has been already cherry-picked.
        post :cherry_pick, params: { namespace_id: project.namespace, project_id: project, start_branch: 'master', id: master_pickable_commit.id }

        expect(response).to redirect_to project_commit_path(project, master_pickable_commit.id)
        expect(flash[:alert]).to match('Commit cherry-pick failed:')
      end
    end

    context 'in the context of a merge_request' do
      let(:merge_request) { create(:merge_request, :merged, source_project: project) }
      let(:repository) { project.repository }

      before do
        merge_commit_id = repository.merge(user,
          merge_request.diff_head_sha,
          merge_request,
          'Test message')
        repository.commit(merge_commit_id)
        merge_request.update!(merge_commit_sha: merge_commit_id)
      end

      context 'when the cherry_pick was successful' do
        it 'redirects to the merge request page' do
          post :cherry_pick, params: { namespace_id: project.namespace, project_id: project, start_branch: 'merge-test', id: merge_request.merge_commit_sha }

          expect(response).to redirect_to project_merge_request_path(project, merge_request)
          expect(flash[:notice]).to eq('The merge request has been successfully cherry-picked into merge-test.')
        end
      end

      context 'when the cherry_pick failed' do
        before do
          post :cherry_pick, params: { namespace_id: project.namespace, project_id: project, start_branch: 'merge-test', id: merge_request.merge_commit_sha }
        end

        it 'redirects to the merge request page' do
          # Reverting a merge request that has been already cherry-picked.
          post :cherry_pick, params: { namespace_id: project.namespace, project_id: project, start_branch: 'merge-test', id: merge_request.merge_commit_sha }

          expect(response).to redirect_to project_merge_request_path(project, merge_request)
          expect(flash[:alert]).to match('Merge request cherry-pick failed:')
        end
      end
    end

    context 'when a project has a fork' do
      let(:project) { create(:project, :repository) }
      let(:forked_project) { fork_project(project, user, namespace: user.namespace, repository: true) }
      let(:target_project) { project }
      let(:create_merge_request) { nil }

      let(:commit_id) do
        forked_project.repository.commit_files(
          user,
          branch_name: 'feature', message: 'Commit to feature',
          actions: [{ action: :create, file_path: 'encoding/CHANGELOG', content: 'New content' }]
        )
      end

      def send_request
        post :cherry_pick, params: {
          namespace_id: forked_project.namespace,
          project_id: forked_project,
          target_project_id: target_project.id,
          start_branch: 'feature',
          id: commit_id,
          create_merge_request: create_merge_request
        }
      end

      def merge_request_url(source_project, branch)
        project_new_merge_request_path(
          source_project,
          merge_request: {
            target_project_id: project.id,
            source_branch: branch,
            target_branch: 'feature'
          }
        )
      end

      before do
        forked_project.add_maintainer(user)
      end

      it 'successfully cherry picks a commit from fork to upstream project' do
        send_request

        expect(response).to redirect_to project_commits_path(project, 'feature')
        expect(flash[:notice]).to eq('The commit has been successfully cherry-picked into feature.')
        expect(project.commit('feature').message).to include(commit_id)
      end

      context 'when the cherry pick is performed via merge request' do
        let(:create_merge_request) { true }

        it 'successfully cherry picks a commit from fork to a cherry pick branch' do
          branch = forked_project.commit(commit_id).cherry_pick_branch_name
          send_request

          expect(response).to redirect_to merge_request_url(project, branch)
          expect(flash[:notice]).to start_with("The commit has been successfully cherry-picked into #{branch}")
          expect(project.commit(branch).message).to include(commit_id)
        end

        it 'uses a branch name that is unique in the upstream project' do
          commit = forked_project.commit(commit_id)
          existing_branch = "cherry-pick-#{commit.short_id}"
          project.repository.add_branch(user, existing_branch, project.commit('feature').id)
          existing_branch_oid = project.commit(existing_branch).id
          new_branch = project.repository.next_branch(existing_branch, mild: true)

          expect(forked_project.repository.branch_exists?(existing_branch)).to be(false)

          send_request

          aggregate_failures do
            expect(project.commit(existing_branch).id).to eq(existing_branch_oid)
            expect(response).to redirect_to merge_request_url(project, new_branch)
            expect(flash[:notice]).to start_with("The commit has been successfully cherry-picked into #{new_branch}")
            expect(project.commit(new_branch)&.message).to include(commit_id)
          end
        end
      end

      context 'when a user cannot push to upstream project' do
        let(:create_merge_request) { true }
        let(:branch) { forked_project.commit(commit_id).cherry_pick_branch_name }

        before do
          project.repository.add_branch(user, branch, project.commit('feature').id)
          project.add_reporter(user)
        end

        it 'cherry picks a commit to the fork' do
          upstream_branch_oid = project.commit(branch).id

          send_request

          expect(response).to redirect_to merge_request_url(forked_project, branch)
          expect(flash[:notice]).to start_with("The commit has been successfully cherry-picked into #{branch}")
          expect(project.commit(branch).id).to eq(upstream_branch_oid)
          expect(project.commit('feature').message).not_to include(commit_id)
          expect(forked_project.commit(branch).message).to include(commit_id)
        end
      end

      context 'when a user do not have access to the target project' do
        let(:target_project) { create(:project, :private) }

        it 'cherry picks a commit to the fork' do
          send_request

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end
    end
  end

  describe 'GET pipelines' do
    def get_pipelines(extra_params = {})
      params = {
        namespace_id: project.namespace,
        project_id: project
      }

      get :pipelines, params: params.merge(extra_params)
    end

    context 'when the commit exists' do
      context 'when the commit has pipelines' do
        before do
          build.run
        end

        context 'when rendering a HTML format' do
          before do
            get_pipelines(id: commit.id)
          end

          it 'shows pipelines' do
            expect(response).to be_ok
          end

          it 'defines last pipeline information' do
            expect(assigns(:last_pipeline)).to have_attributes(id: pipeline.id, status: 'running')
            expect(assigns(:last_pipeline_stages)).not_to be_empty
          end

          it 'defines commit vars' do
            expect(assigns(:diffs)).to be_present
          end
        end

        context 'when rendering a JSON format' do
          it 'responds with serialized pipelines without loading HTML-only data', :aggregate_failures do
            expect(StageSerializer).not_to receive(:new)
            expect(Environments::EnvironmentsByDeploymentsFinder).not_to receive(:new)

            get_pipelines(id: commit.id, format: :json)

            expect(response).to be_ok
            expect(json_response['pipelines']).not_to be_empty
            expect(json_response['count']['all']).to eq 1
            expect(response).to include_pagination_headers
            expect(assigns(:last_pipeline)).to be_nil
          end

          context 'with pagination' do
            let!(:extra_pipeline) { create(:ci_pipeline, project: project, ref: project.default_branch, sha: commit.sha, status: :running) }

            it 'paginates the result when ref is blank' do
              allow(Ci::Pipeline).to receive(:default_per_page).and_return(1)

              get_pipelines(id: commit.id, format: :json)

              expect(json_response['pipelines'].count).to eq(1)
            end

            it 'paginates the result when ref is present' do
              allow(Ci::Pipeline).to receive(:default_per_page).and_return(1)

              get_pipelines(id: commit.id, ref: project.default_branch, format: :json)

              expect(json_response['pipelines'].count).to eq(1)
            end

            context 'while being on last page' do
              it 'paginates the result when ref is present' do
                allow(Ci::Pipeline).to receive(:default_per_page).and_return(1)

                get_pipelines(id: commit.id, ref: project.default_branch, page: 2, format: :json)

                expect(json_response['pipelines'].count).to eq(1)
                expect(json_response['count']['all']).to eq 2
              end
            end

            context 'when page is invalid' do
              it 'does not fail' do
                get_pipelines(id: commit.id, ref: project.default_branch, page: ['wrong'], format: :json)

                expect(json_response['pipelines'].count).to eq(2)
                expect(json_response['count']['all']).to eq 2
              end
            end
          end
        end
      end
    end

    context 'when the commit does not exist' do
      before do
        get_pipelines(id: 'e7a412c8da9f6d0081a633a4a402dde1c4694ebd')
      end

      it 'returns a 404' do
        expect(response).to have_gitlab_http_status(:not_found)
      end
    end
  end
end
