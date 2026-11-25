# frozen_string_literal: true

require 'spec_helper'
require 'labkit/rspec/matchers'

RSpec.describe API::MergeRequests, :aggregate_failures, feature_category: :source_code_management do
  include_context 'with merge requests API setup'

  describe 'POST /projects/:id/merge_requests/:merge_request_iid/pipelines' do
    before do
      stub_ci_pipeline_yaml_file(ci_yaml)
    end

    let(:ci_yaml) do
      YAML.dump({
        rspec: {
          script: 'ls',
          only: ['merge_requests']
        }
      })
    end

    let_it_be(:project) do
      create(:project, :private, :repository,
        creator: user,
        namespace: user.namespace,
        only_allow_merge_if_pipeline_succeeds: false)
    end

    let_it_be(:merge_request, freeze: false) do
      create(:merge_request, :with_detached_merge_request_pipeline,
        author: user,
        assignees: [user],
        source_project: project,
        target_project: project,
        title: 'Test',
        created_at: base_time)
    end

    let(:merge_request_iid)  { merge_request.iid }
    let(:authenticated_user) { user }

    let(:request) do
      post api("/projects/#{project.id}/merge_requests/#{merge_request_iid}/pipelines", authenticated_user)
    end

    context 'when authorized' do
      it 'creates and returns the new Pipeline' do
        expect { request }.to change { Ci::Pipeline.count }.by(1)
        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response).to be_a Hash
      end

      context 'when async is requested', :sidekiq_inline do
        let(:request) do
          post api("/projects/#{project.id}/merge_requests/#{merge_request_iid}/pipelines", authenticated_user),
            params: { async: true }
        end

        it 'creates the pipeline async' do
          expect(MergeRequests::CreatePipelineWorker).to receive(:perform_async).and_call_original

          expect { request }.to change { Ci::Pipeline.count }.by(1)

          expect(response).to have_gitlab_http_status(:accepted)
        end

        it 'stores the pipeline creation request as user initiated', :clean_gitlab_redis_shared_state do
          request

          requests = Ci::PipelineCreation::Requests.for_merge_request(merge_request)
          expect(requests).to contain_exactly(a_hash_including('user_initiated' => true))
        end
      end

      it_behaves_like 'authorizing granular token permissions', :create_merge_request_pipeline do
        let(:boundary_object) { project }
        let(:request) do
          post api("/projects/#{project.id}/merge_requests/#{merge_request.iid}/pipelines", personal_access_token: pat)
        end
      end
    end

    context 'with oauth token that has ai_workflows scope' do
      let(:token) { create(:oauth_access_token, user: authenticated_user, scopes: [:ai_workflows]) }

      it 'does not allow access' do
        post api("/projects/#{project.id}/merge_requests/#{merge_request_iid}/pipelines", oauth_access_token: token),
          params: { async: true }

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end

    context 'when unauthorized' do
      let(:authenticated_user) { create(:user) }

      it 'responds with a blank 404' do
        expect { request }.not_to change { Ci::Pipeline.count }
        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context 'when the merge request does not exist' do
      let(:merge_request_iid) { non_existing_record_id }

      it 'responds with a blank 404' do
        expect { request }.not_to change { Ci::Pipeline.count }
        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context 'when the .gitlab-ci.yml file is invalid' do
      let(:ci_yaml) { 'invalid yaml file' }

      it 'creates a failed pipeline' do
        expect { request }.to change { Ci::Pipeline.count }.by(1)
        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response).to be_a Hash
        expect(merge_request.pipelines_for_merge_request.last).to be_failed
        expect(merge_request.pipelines_for_merge_request.last).to be_config_error
      end
    end

    context 'when pipeline creation fails' do
      it 'returns error response when pipeline is nil' do
        allow_next_instance_of(::MergeRequests::CreatePipelineService) do |service|
          allow(service).to receive(:execute).and_return(ServiceResponse.success(payload: nil))
        end

        post api("/projects/#{project.id}/merge_requests/#{merge_request.iid}/pipelines", user)

        expect(response).to have_gitlab_http_status(:method_not_allowed)
      end

      it 'returns validation error when pipeline is not persisted' do
        invalid_pipeline = build(:ci_pipeline, project: project)
        invalid_pipeline.errors.add(:base, 'Pipeline could not be created')

        allow_next_instance_of(::MergeRequests::CreatePipelineService) do |service|
          allow(service).to receive(:execute).and_return(ServiceResponse.success(payload: invalid_pipeline))
        end

        post api("/projects/#{project.id}/merge_requests/#{merge_request.iid}/pipelines", user)

        expect(response).to have_gitlab_http_status(:bad_request)
        expect(json_response['message']['base']).to include('Pipeline could not be created')
      end
    end
  end

  describe 'POST /projects/:id/merge_requests' do
    context 'when request exceeds the rate limit' do
      before do
        allow(Gitlab::ApplicationRateLimiter).to receive(:throttled?).and_call_original
        allow(Gitlab::ApplicationRateLimiter).to receive(:throttled?)
          .with(:merge_requests_create, anything).and_return(true)
      end

      it 'returns too many requests without creating a merge request' do
        expect do
          post api("/projects/#{project.id}/merge_requests", user),
            params: { title: 'Test merge request', source_branch: 'feature_conflict', target_branch: 'master' }
        end.not_to change { MergeRequest.count }

        expect(response).to have_gitlab_http_status(:too_many_requests)
      end
    end

    describe 'mcp route setting' do
      subject do
        post api("/projects/#{project.id}/merge_requests", user),
          params: { title: 'Test merge request', source_branch: 'feature_conflict', target_branch: 'master' }
      end

      it_behaves_like 'an endpoint with mcp route setting', :create_merge_request,
        expected_params: API::Helpers::MergeRequestsHelpers.create_merge_request_mcp_params, status: :created
    end

    context 'with the deprecated assignee_id param' do
      let(:params) do
        {
          title: 'Test merge request',
          source_branch: 'feature_conflict',
          target_branch: 'master',
          author_id: user.id,
          assignee_id: user2.id
        }
      end

      context 'with oauth token that has ai_workflows scope' do
        let(:token) { create(:oauth_access_token, user: user, scopes: [:ai_workflows]) }

        it "creates a new merge request" do
          post api("/projects/#{project.id}/merge_requests", oauth_access_token: token), params: params

          expect(response).to have_gitlab_http_status(:created)
          expect(json_response['title']).to eq('Test merge request')
          expect(json_response['assignee']['name']).to eq(user2.name)
          expect(json_response['assignees'].first['name']).to eq(user2.name)
        end

        it "creates a new merge request for a project passed as a full path" do
          post api(
            "/projects/#{CGI.escape(project.full_path)}/merge_requests",
            oauth_access_token: token
          ), params: params

          expect(response).to have_gitlab_http_status(:created)
          expect(json_response['title']).to eq('Test merge request')
          expect(json_response['assignee']['name']).to eq(user2.name)
          expect(json_response['assignees'].first['name']).to eq(user2.name)
        end
      end

      it_behaves_like 'authorizing granular token permissions', :create_merge_request do
        let(:boundary_object) { project }
        let(:request) do
          post api("/projects/#{project.id}/merge_requests", personal_access_token: pat), params: params
        end
      end

      it 'creates a new merge request' do
        post api("/projects/#{project.id}/merge_requests", user), params: params

        expect(response).to have_gitlab_http_status(:created)
        expect(json_response['title']).to eq('Test merge request')
        expect(json_response['assignee']['name']).to eq(user2.name)
        expect(json_response['assignees'].first['name']).to eq(user2.name)
      end

      it 'starts covered experience' do
        expect do
          post api("/projects/#{project.id}/merge_requests", user), params: params
        end.to start_user_experience(:create_merge_request)
      end

      it 'creates a new merge request when assignee_id is empty' do
        params[:assignee_id] = ''

        post api("/projects/#{project.id}/merge_requests", user), params: params

        expect(response).to have_gitlab_http_status(:created)
        expect(json_response['title']).to eq('Test merge request')
        expect(json_response['assignee']).to be_nil
      end
    end

    context 'with single assignee restrictions' do
      let(:params) do
        {
          title: 'Test merge request',
          source_branch: 'feature_conflict',
          target_branch: 'master',
          author_id: user.id,
          assignee_ids: [user.id, user2.id]
        }
      end

      it 'creates a new project merge request with no more than one assignee' do
        post api("/projects/#{project.id}/merge_requests", user), params: params

        expect(response).to have_gitlab_http_status(:created)
        expect(json_response['title']).to eq('Test merge request')
        expect(json_response['assignees'].count).to eq(1)
        expect(json_response['assignees'].first['name']).to eq(user.name)
        expect(json_response.dig('assignee', 'name')).to eq(user.name)
      end
    end

    context 'with reviewer_ids' do
      let(:params) do
        {
          title: 'Test merge request',
          source_branch: 'feature_conflict',
          target_branch: 'master',
          author_id: user.id,
          reviewer_ids: [user2.id]
        }
      end

      it 'creates a new merge request with a reviewer' do
        post api("/projects/#{project.id}/merge_requests", user), params: params

        expect(response).to have_gitlab_http_status(:created)
        expect(json_response['title']).to eq('Test merge request')
        expect(json_response['reviewers'].first['name']).to eq(user2.name)
      end

      it 'creates a new merge request with no reviewer' do
        params[:reviewer_ids] = []

        post api("/projects/#{project.id}/merge_requests", user), params: params

        expect(response).to have_gitlab_http_status(:created)
        expect(json_response['title']).to eq('Test merge request')
        expect(json_response['reviewers']).to be_empty
      end
    end

    context 'with branches in the same project' do
      context 'with different labels' do
        let(:params) do
          {
            title: 'Test merge_request',
            source_branch: 'feature_conflict',
            target_branch: 'master',
            author_id: user.id,
            milestone_id: milestone.id,
            squash: true
          }
        end

        shared_examples_for 'creates merge request with labels' do
          it 'returns merge_request' do
            params[:labels] = labels
            post api("/projects/#{project.id}/merge_requests", user), params: params

            expect(response).to have_gitlab_http_status(:created)
            expect(json_response['title']).to eq('Test merge_request')
            expect(json_response['labels']).to eq(%w[label label2])
            expect(json_response['milestone']['id']).to eq(milestone.id)
            expect(json_response['squash']).to be_truthy
            expect(json_response['force_remove_source_branch']).to be_truthy
          end
        end

        it_behaves_like 'creates merge request with labels' do
          let(:labels) { 'label, label2' }
        end

        it_behaves_like 'creates merge request with labels' do
          let(:labels) { %w[label label2] }
        end

        it 'creates merge request with special label names' do
          params[:labels] = 'label, label?, label&foo, ?, &'
          post api("/projects/#{project.id}/merge_requests", user), params: params

          expect(response).to have_gitlab_http_status(:created)
          expect(json_response['labels']).to include 'label'
          expect(json_response['labels']).to include 'label?'
          expect(json_response['labels']).to include 'label&foo'
          expect(json_response['labels']).to include '?'
          expect(json_response['labels']).to include '&'
        end

        it 'creates merge request with special label names as array' do
          params[:labels] = ['label', 'label?', 'label&foo, ?, &', '1, 2', 3, 4]
          post api("/projects/#{project.id}/merge_requests", user), params: params

          expect(response).to have_gitlab_http_status(:created)
          expect(json_response['labels']).to include 'label'
          expect(json_response['labels']).to include 'label?'
          expect(json_response['labels']).to include 'label&foo'
          expect(json_response['labels']).to include '?'
          expect(json_response['labels']).to include '&'
          expect(json_response['labels']).to include '1'
          expect(json_response['labels']).to include '2'
          expect(json_response['labels']).to include '3'
          expect(json_response['labels']).to include '4'
        end

        it 'empty label param does not add any labels' do
          params[:labels] = ''
          post api("/projects/#{project.id}/merge_requests", user), params: params

          expect(response).to have_gitlab_http_status(:created)
          expect(json_response['labels']).to eq([])
        end

        it 'empty label param as array does not add any labels, but only explicitly as json' do
          params[:labels] = []
          post api("/projects/#{project.id}/merge_requests", user),
            params: params.to_json,
            headers: { 'Content-Type': 'application/json' }

          expect(response).to have_gitlab_http_status(:created)
          expect(json_response['labels']).to eq([])
        end

        it 'array with one empty string element does not add labels' do
          params[:labels] = ['']
          post api("/projects/#{project.id}/merge_requests", user), params: params

          expect(response).to have_gitlab_http_status(:created)
          expect(json_response['labels']).to eq([])
        end

        it 'array with multiple empty string elements, does not add labels' do
          params[:labels] = ['', '', '']
          post api("/projects/#{project.id}/merge_requests", user), params: params

          expect(response).to have_gitlab_http_status(:created)
          expect(json_response['labels']).to eq([])
        end
      end

      it "returns 422 when source_branch equals target_branch" do
        post api("/projects/#{project.id}/merge_requests", user),
          params: { title: "Test merge_request", source_branch: "master", target_branch: "master", author: user }

        expect(response).to have_gitlab_http_status(:unprocessable_entity)
        expect(json_response['message']).to eq(["You can't use same project/branch for source and target"])
      end

      it "returns 400 when source_branch is missing" do
        post api("/projects/#{project.id}/merge_requests", user),
          params: { title: "Test merge_request", target_branch: "master", author: user }

        expect(response).to have_gitlab_http_status(:bad_request)
        expect(json_response['error']).to eq('source_branch is missing')
      end

      it "returns 400 when target_branch is missing" do
        post api("/projects/#{project.id}/merge_requests", user),
          params: { title: "Test merge_request", source_branch: "markdown", author: user }

        expect(response).to have_gitlab_http_status(:bad_request)
        expect(json_response['error']).to eq('target_branch is missing')
      end

      it "returns 400 when source_branch does not exist in the repository" do
        post api("/projects/#{project.id}/merge_requests", user),
          params: { title: "Test merge_request", source_branch: "non-existent-source", target_branch: "master",
                    author: user }

        expect(response).to have_gitlab_http_status(:bad_request)
        expect(json_response['message']).to eq({ 'source_branch' => ['does not exist'] })
      end

      it "returns 400 when target_branch does not exist in the repository" do
        post api("/projects/#{project.id}/merge_requests", user),
          params: { title: "Test merge_request", source_branch: "markdown", target_branch: "non-existent-target",
                    author: user }

        expect(response).to have_gitlab_http_status(:bad_request)
        expect(json_response['message']).to eq({ 'target_branch' => ['does not exist'] })
      end

      it "returns 400 when title is missing" do
        post api("/projects/#{project.id}/merge_requests", user),
          params: { target_branch: 'master', source_branch: 'markdown' }

        expect(response).to have_gitlab_http_status(:bad_request)
        expect(json_response['error']).to eq('title is missing')
      end

      context 'with existing MR' do
        before do
          post api("/projects/#{project.id}/merge_requests", user),
            params: {
              title: 'Test merge_request',
              source_branch: 'feature_conflict',
              target_branch: 'master',
              author: user
            }
          @mr = MergeRequest.all.last
        end

        it 'returns 409 when MR already exists for source/target' do
          expect do
            post api("/projects/#{project.id}/merge_requests", user),
              params: {
                title: 'New test merge_request',
                source_branch: 'feature_conflict',
                target_branch: 'master',
                author: user
              }
          end.not_to change { MergeRequest.count }

          expect(response).to have_gitlab_http_status(:conflict)
          expect(json_response['message'])
            .to eq(["Another open merge request already exists for this source branch: !1"])
        end
      end

      context 'with the remove_source_branch param' do
        let(:params) do
          { title: 'Test merge_request',
            source_branch: 'feature_conflict',
            target_branch: 'master',
            author: user }
        end

        it 'sets force_remove_source_branch to false' do
          post api("/projects/#{project.id}/merge_requests", user), params: params.merge(remove_source_branch: false)

          expect(json_response['force_remove_source_branch']).to be_falsy
        end
      end

      context 'with project squash settings' do
        let(:params) do
          {
            title: 'Test merge_request',
            source_branch: 'feature_conflict',
            target_branch: 'master'
          }
        end

        it 'defaults squash to project setting when not provided' do
          project.project_setting.update!(squash_option: :default_on)

          post api("/projects/#{project.id}/merge_requests", user), params: params

          expect(response).to have_gitlab_http_status(:created)
          expect(json_response['squash']).to be true
        end

        it 'respects explicit squash param over project default' do
          project.project_setting.update!(squash_option: :default_on)

          post api("/projects/#{project.id}/merge_requests", user), params: params.merge(squash: false)

          expect(response).to have_gitlab_http_status(:created)
          expect(json_response['squash']).to be false
        end
      end
    end

    context 'with forked projects', :sidekiq_might_not_need_inline do
      let_it_be(:user2, freeze: false) { create(:user) }

      let_it_be_with_refind(:project) { create(:project, :public, :repository) }
      let_it_be_with_refind(:forked_project) { fork_project(project, user2, repository: true) }
      let(:unrelated_project) { create(:project, namespace: create(:user).namespace, creator_id: user2.id) }

      before_all do
        forked_project.add_reporter(user2)
      end

      it "returns merge_request" do
        post api("/projects/#{forked_project.id}/merge_requests", user2),
          params: {
            title: 'Test merge_request',
            source_branch: "feature_conflict",
            target_branch: "master",
            author: user2,
            target_project_id: project.id,
            description: 'Test description for Test merge_request'
          }

        expect(response).to have_gitlab_http_status(:created)
        expect(json_response['title']).to eq('Test merge_request')
        expect(json_response['description']).to eq('Test description for Test merge_request')
      end

      it 'ignores merge_after when the user cannot set merge request metadata on the target project' do
        post api("/projects/#{forked_project.id}/merge_requests", user2),
          params: {
            title: 'Test merge_request',
            source_branch: 'feature_conflict',
            target_branch: 'master',
            target_project_id: project.id,
            merge_after: '2025-01-09T20:47+0100'
          }

        expect(response).to have_gitlab_http_status(:created)
        expect(json_response['merge_after']).to be_nil
      end

      it "does not return 422 when source_branch equals target_branch" do
        expect(project.id).not_to eq(forked_project.id)
        expect(forked_project.forked?).to be_truthy
        expect(forked_project.forked_from_project).to eq(project)
        post api("/projects/#{forked_project.id}/merge_requests", user2),
          params: {
            title: 'Test merge_request',
            source_branch: "master",
            target_branch: "master",
            author: user2,
            target_project_id: project.id
          }

        expect(response).to have_gitlab_http_status(:created)
        expect(json_response['title']).to eq('Test merge_request')
      end

      it 'returns 403 when target project has disabled merge requests' do
        project.project_feature.update!(merge_requests_access_level: 0)

        post api("/projects/#{forked_project.id}/merge_requests", user2),
          params: {
            title: 'Test',
            target_branch: 'master',
            source_branch: 'markdown',
            author: user2,
            target_project_id: project.id
          }

        expect(response).to have_gitlab_http_status(:forbidden)
      end

      it 'allows setting `allow_collaboration`', :sidekiq_might_not_need_inline do
        post api("/projects/#{forked_project.id}/merge_requests", user2),
          params: {
            title: 'Test merge_request',
            source_branch: "feature_conflict",
            target_branch: "master",
            author: user2,
            target_project_id: project.id,
            allow_collaboration: true
          }

        expect(response).to have_gitlab_http_status(:created)
        expect(json_response['allow_collaboration']).to be_truthy
        expect(json_response['allow_maintainer_to_push']).to be_truthy
      end

      context 'when target_branch and target_project_id is specified' do
        let(:params) do
          {
            title: 'Test merge_request',
            target_branch: 'master',
            source_branch: 'markdown',
            author: user2,
            target_project_id: unrelated_project.id
          }
        end

        it 'returns 422 if targeting a different fork' do
          unrelated_project.add_developer(user2)

          post api("/projects/#{forked_project.id}/merge_requests", user2), params: params

          expect(response).to have_gitlab_http_status(:unprocessable_entity)
        end

        it 'returns 403 if targeting a different fork which user can not access' do
          post api("/projects/#{forked_project.id}/merge_requests", user2), params: params

          expect(response).to have_gitlab_http_status(:forbidden)
        end
      end

      it "returns 201 when target_branch is specified and for the same project", :sidekiq_might_not_need_inline do
        post api("/projects/#{forked_project.id}/merge_requests", user2),
          params: {
            title: 'Test merge_request',
            target_branch: 'master',
            source_branch: 'markdown',
            author: user2,
            target_project_id: forked_project.id
          }

        expect(response).to have_gitlab_http_status(:created)
      end
    end

    context 'when user is an inherited member from the group' do
      let_it_be(:group) { create(:group) }

      shared_examples 'user cannot create merge requests' do
        it 'returns 403 forbidden' do
          post api("/projects/#{group_project.id}/merge_requests", inherited_user), params: params

          expect(response).to have_gitlab_http_status(:forbidden)
        end
      end

      context 'and user is a guest' do
        let_it_be(:inherited_user) { create(:user) }
        let_it_be(:params) do
          {
            title: 'Test merge request',
            source_branch: 'feature_conflict',
            target_branch: 'master',
            author_id: inherited_user.id
          }
        end

        before_all do
          group.add_guest(inherited_user)
        end

        context 'when project is public with private merge requests' do
          let(:group_project) do
            create(
              :project,
              :public,
              :repository,
              group: group,
              merge_requests_access_level: ProjectFeature::DISABLED,
              only_allow_merge_if_pipeline_succeeds: false
            )
          end

          it_behaves_like 'user cannot create merge requests'
        end

        context 'when project is private' do
          let(:group_project) do
            create(
              :project,
              :private,
              :repository,
              group: group,
              only_allow_merge_if_pipeline_succeeds: false
            )
          end

          it_behaves_like 'user cannot create merge requests'
        end
      end
    end

    context 'when user is using a composite identity', :request_store, :sidekiq_inline do
      let(:user) { create(:user, :service_account, username: 'user-with-composite-identity') }

      let(:params) do
        {
          title: 'Test merge request',
          source_branch: 'markdown',
          target_branch: 'master',
          author_id: user.id
        }
      end

      before do
        user.update!(composite_identity_enforced: true)
      end

      context 'when composite identity is missing' do
        it 'responds with 401 unauthorized http status' do
          post api("/projects/#{project.id}/merge_requests", user), params: params

          expect(response).to have_gitlab_http_status(:unauthorized)
        end
      end

      context 'when composite identity is defined' do
        # Not the shared `user2`: resolve_composite_identity_user calls composite_identity_enforced!,
        # which sets an in-memory ivar that would leak to later tests through the let_it_be object.
        let(:human_user) { create(:user, developer_of: project) }

        before do
          ::Gitlab::Auth::Identity.new(user).link!(human_user, context: :authentication)
        end

        context 'when both users can create a merge request' do
          before do
            project.add_developer(user)
            project.add_developer(human_user)
          end

          it 'creates a merge request' do
            post api("/projects/#{project.id}/merge_requests", user), params: params

            expect(response).to have_gitlab_http_status(:created)
          end
        end

        context 'when scoped user can not create a merge request' do
          before do
            project.add_developer(user)
            project.add_reporter(human_user)
          end

          it 'does not create a merge request' do
            post api("/projects/#{project.id}/merge_requests", user), params: params

            expect(response).to have_gitlab_http_status(:forbidden)
          end
        end
      end
    end

    context 'with milestone' do
      let(:base_params) do
        {
          title: 'Test merge_request',
          source_branch: 'feature_conflict',
          target_branch: 'master',
          author_id: user.id
        }
      end

      context 'with milestone_id' do
        it 'creates the merge_request without a milestone when milestone_id is invalid' do
          post api("/projects/#{project.id}/merge_requests", user),
            params: base_params.merge(milestone_id: non_existing_record_id)

          expect(response).to have_gitlab_http_status(:created)
          expect(json_response['milestone']).to be_nil
        end
      end

      context 'with milestone title' do
        it 'returns merge_request with milestone assigned' do
          post api("/projects/#{project.id}/merge_requests", user),
            params: base_params.merge(milestone: milestone.title)

          expect(response).to have_gitlab_http_status(:created)
          expect(json_response['milestone']['id']).to eq(milestone.id)
        end

        it 'creates the merge_request without a milestone when no milestone in scope has the title' do
          post api("/projects/#{project.id}/merge_requests", user),
            params: base_params.merge(milestone: 'nonexistent')

          expect(response).to have_gitlab_http_status(:created)
          expect(json_response['milestone']).to be_nil
        end
      end

      it 'returns 400 when both milestone and milestone_id are provided' do
        post api("/projects/#{project.id}/merge_requests", user),
          params: base_params.merge(milestone: milestone.title, milestone_id: milestone.id)

        expect(response).to have_gitlab_http_status(:bad_request)
      end

      it 'returns 400 when milestone title exceeds the length limit' do
        post api("/projects/#{project.id}/merge_requests", user),
          params: base_params.merge(milestone: 'a' * 256)

        expect(response).to have_gitlab_http_status(:bad_request)
        expect(json_response['error']).to include('milestone must be less than 255 characters')
      end
    end
  end

  shared_examples 'context commits write rate limit' do
    it_behaves_like 'rate limited endpoint', rate_limit_key: :context_commits_write do
      let(:current_user) { authenticated_user }

      def request
        context_commits_request(authenticated_user)
      end

      def request_with_second_scope
        context_commits_request(create(:user, developer_of: project))
      end
    end

    it 'does not check the rate limit when the user cannot update the merge request' do
      expect(Gitlab::ApplicationRateLimiter).not_to receive(:throttled_request?)
        .with(anything, anything, :context_commits_write, any_args)

      context_commits_request(create(:user, reporter_of: project))

      expect(response).to have_gitlab_http_status(:forbidden)
    end

    context 'when rate_limit_context_commits_write is disabled' do
      before do
        stub_feature_flags(rate_limit_context_commits_write: false)
      end

      it 'does not check the rate limit' do
        expect(Gitlab::ApplicationRateLimiter).not_to receive(:throttled_request?)
          .with(anything, anything, :context_commits_write, any_args)

        context_commits_request(authenticated_user)

        expect(response).not_to have_gitlab_http_status(:too_many_requests)
      end
    end
  end

  describe "POST /projects/:id/merge_requests/:merge_request_iid/context_commits" do
    include_context 'with a merge request created once'

    let(:merge_request_iid)  { merge_request.iid }
    let(:authenticated_user) { user }
    let(:commit) { project.repository.commit }

    let(:params) do
      {
        commits: [commit.id]
      }
    end

    let(:params_empty_commits) do
      {
        commits: []
      }
    end

    let(:params_invalid_shas) do
      {
        commits: ['invalid']
      }
    end

    def context_commits_request(request_user)
      post api("/projects/#{project.id}/merge_requests/#{merge_request_iid}/context_commits", request_user),
        params: params
    end

    describe 'when authenticated' do
      it 'creates and returns the new context commit' do
        post api("/projects/#{project.id}/merge_requests/#{merge_request_iid}/context_commits", authenticated_user),
          params: params
        expect(response).to have_gitlab_http_status(:created)
        expect(json_response).to be_an Array
        expect(json_response.first['short_id']).to eq(commit.short_id)
        expect(json_response.first['title']).to eq(commit.title)
        expect(json_response.first['message']).to eq(commit.message)
        expect(json_response.first['author_name']).to eq(commit.author_name)
        expect(json_response.first['author_email']).to eq(commit.author_email)
        expect(json_response.first['committer_name']).to eq(commit.committer_name)
        expect(json_response.first['committer_email']).to eq(commit.committer_email)
      end

      context 'with oauth token that has ai_workflows scope' do
        let(:token) { create(:oauth_access_token, user: authenticated_user, scopes: [:ai_workflows]) }

        it 'does not allow access' do
          post api("/projects/#{project.id}/merge_requests/#{merge_request_iid}/context_commits",
            oauth_access_token: token),
            params: params

          expect(response).to have_gitlab_http_status(:forbidden)
        end
      end

      context 'when the context commit already exists' do
        before do
          create(:merge_request_context_commit, merge_request: merge_request, sha: commit.id)
        end

        it 'returns 400 when the context commit is already created' do
          post api("/projects/#{project.id}/merge_requests/#{merge_request_iid}/context_commits", authenticated_user),
            params: params
          expect(response).to have_gitlab_http_status(:bad_request)
          expect(json_response['message']).to eq("Context commits: [\"#{commit.id}\"] are already created")
        end
      end

      it 'returns 400 when one or more shas are invalid' do
        post api("/projects/#{project.id}/merge_requests/#{merge_request_iid}/context_commits", authenticated_user),
          params: params_invalid_shas
        expect(response).to have_gitlab_http_status(:bad_request)
        expect(json_response['message']).to eq('One or more context commits\' sha is not valid.')
      end

      it 'returns 400 when the commits are empty' do
        post api("/projects/#{project.id}/merge_requests/#{merge_request_iid}/context_commits", authenticated_user),
          params: params_empty_commits
        expect(response).to have_gitlab_http_status(:bad_request)
      end

      it 'returns 400 when params is empty' do
        post api("/projects/#{project.id}/merge_requests/#{merge_request_iid}/context_commits", authenticated_user)
        expect(response).to have_gitlab_http_status(:bad_request)
      end

      it 'returns 403 when creating new context commit for guest role' do
        guest = create(:user)
        project.add_guest(guest)
        post api("/projects/#{project.id}/merge_requests/#{merge_request_iid}/context_commits", guest), params: params
        expect(response).to have_gitlab_http_status(:forbidden)
      end

      it_behaves_like 'authorizing granular token permissions', :create_merge_request_context_commit do
        let(:boundary_object) { project }
        let(:request) do
          post api("/projects/#{project.id}/merge_requests/#{merge_request.iid}/context_commits",
            personal_access_token: pat),
            params: { commits: [commit.id] }
        end
      end

      it_behaves_like 'context commits write rate limit'
    end

    context 'when unauthenticated' do
      it 'returns 401 if user tries to create context commits' do
        post api("/projects/#{project.id}/merge_requests/#{merge_request_iid}/context_commits"), params: params
        expect(response).to have_gitlab_http_status(:unauthorized)
      end
    end
  end

  describe "DELETE /projects/:id/merge_requests/:merge_request_iid/context_commits" do
    include_context 'with a merge request created once'

    let(:merge_request_iid)  { merge_request.iid }
    let(:authenticated_user) { user }
    let(:commit) { project.repository.commit }

    def context_commits_request(request_user)
      delete api("/projects/#{project.id}/merge_requests/#{merge_request_iid}/context_commits", request_user),
        params: params
    end

    context "when authenticated" do
      let(:params) do
        {
          commits: [commit.id]
        }
      end

      let(:params_invalid_shas) do
        {
          commits: ["invalid"]
        }
      end

      let(:params_empty_commits) do
        {
          commits: []
        }
      end

      it "deletes context commit" do
        delete api("/projects/#{project.id}/merge_requests/#{merge_request.iid}/context_commits", authenticated_user),
          params: params

        expect(response).to have_gitlab_http_status(:no_content)
      end

      it "returns 400 when invalid commit sha is passed" do
        delete api("/projects/#{project.id}/merge_requests/#{merge_request.iid}/context_commits", authenticated_user),
          params: params_invalid_shas

        expect(response).to have_gitlab_http_status(:bad_request)
        expect(json_response["message"]).to eq('One or more context commits\' sha is not valid.')
      end

      it "returns 400 when commits is empty" do
        delete api("/projects/#{project.id}/merge_requests/#{merge_request.iid}/context_commits", authenticated_user),
          params: params_empty_commits

        expect(response).to have_gitlab_http_status(:bad_request)
      end

      it "returns 400 when no params is passed" do
        delete api("/projects/#{project.id}/merge_requests/#{merge_request.iid}/context_commits", authenticated_user)

        expect(response).to have_gitlab_http_status(:bad_request)
      end

      it 'deletes context commit for developer role' do
        developer = create(:user)
        project.add_developer(developer)
        delete api("/projects/#{project.id}/merge_requests/#{merge_request_iid}/context_commits", developer),
          params: params
        expect(response).to have_gitlab_http_status(:no_content)
      end

      it 'returns 403 when deleting existing context commit for guest role' do
        guest = create(:user)
        project.add_guest(guest)
        delete api("/projects/#{project.id}/merge_requests/#{merge_request_iid}/context_commits", guest), params: params
        expect(response).to have_gitlab_http_status(:forbidden)
      end

      it_behaves_like 'authorizing granular token permissions', :delete_merge_request_context_commit do
        let(:boundary_object) { project }
        let(:request) do
          delete api("/projects/#{project.id}/merge_requests/#{merge_request.iid}/context_commits",
            personal_access_token: pat),
            params: { commits: [commit.id] }
        end
      end

      it_behaves_like 'context commits write rate limit'
    end

    context "when unauthenticated" do
      it "returns 401, unauthorised error" do
        delete api("/projects/#{project.id}/merge_requests/#{merge_request.iid}/context_commits")

        expect(response).to have_gitlab_http_status(:unauthorized)
      end
    end
  end
end
