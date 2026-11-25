# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::MergeRequests, :aggregate_failures, feature_category: :source_code_management do
  include_context 'with merge requests API setup'

  describe 'PUT /projects/:id/merge_requests/:merge_request_iid' do
    context 'with one merge request for all examples' do
      include_context 'with a merge request created once'

      it_behaves_like 'issuable update endpoint' do
        let(:entity) { merge_request }
      end

      describe 'mcp route setting' do
        subject do
          put api("/projects/#{project.id}/merge_requests/#{merge_request.iid}", user),
            params: { title: 'Updated title' }
        end

        it_behaves_like 'an endpoint with mcp route setting', :update_merge_request,
          expected_params: API::Helpers::MergeRequestsHelpers.update_merge_request_mcp_params, status: :ok
      end

      context 'when only assignee_ids are provided' do
        let(:params) do
          {
            assignee_ids: [user2.id]
          }
        end

        it 'sets the assignees' do
          put api("/projects/#{project.id}/merge_requests/#{merge_request.iid}", user), params: params

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response['assignees']).to contain_exactly(
            a_hash_including('name' => user2.name)
          )
        end

        it 'creates appropriate system notes', :sidekiq_inline do
          put api("/projects/#{project.id}/merge_requests/#{merge_request.iid}", user), params: params

          expect(merge_request.notes.system.last.note).to include("assigned to #{user2.to_reference}")
        end

        it 'triggers webhooks', :sidekiq_inline do
          hook = create(:project_hook, merge_requests_events: true, project: merge_request.project)

          expect(WebHookWorker).to receive(:perform_async).with(hook.id, anything, 'merge_request_hooks', anything)

          put api("/projects/#{project.id}/merge_requests/#{merge_request.iid}", user), params: params

          expect(response).to have_gitlab_http_status(:ok)
        end
      end

      context 'when assignee_id=user2.id' do
        let(:params) do
          {
            assignee_id: user2.id
          }
        end

        it 'sets the assignees' do
          put api("/projects/#{project.id}/merge_requests/#{merge_request.iid}", user), params: params

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response['assignees']).to contain_exactly(
            a_hash_including('name' => user2.name)
          )
        end
      end

      context 'when assignee_id=0' do
        let(:params) do
          {
            assignee_id: 0
          }
        end

        it 'clears the assignees' do
          put api("/projects/#{project.id}/merge_requests/#{merge_request.iid}", user), params: params

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response['assignees']).to be_empty
        end

        it 'creates appropriate system notes', :sidekiq_inline do
          put api("/projects/#{project.id}/merge_requests/#{merge_request.iid}", user), params: params

          expect(merge_request.notes.system.last.note).to include("unassigned #{user.to_reference}")
        end
      end

      context 'when only assignee_ids are provided, and the list is empty' do
        let(:params) do
          {
            assignee_ids: []
          }
        end

        it 'clears the assignees' do
          put api("/projects/#{project.id}/merge_requests/#{merge_request.iid}", user), params: params

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response['assignees']).to be_empty
        end
      end

      context 'when only assignee_ids are provided, and the list contains the sentinel value' do
        let(:params) do
          {
            assignee_ids: [0]
          }
        end

        it 'clears the assignees' do
          put api("/projects/#{project.id}/merge_requests/#{merge_request.iid}", user), params: params

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response['assignees']).to be_empty
        end
      end

      context 'with reviewer_ids' do
        let(:params) do
          {
            title: 'Updated merge request',
            reviewer_ids: [user2.id]
          }
        end

        it 'adds a reviewer to the existing merge request' do
          put api("/projects/#{project.id}/merge_requests/#{merge_request.iid}", user), params: params

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response['title']).to eq('Updated merge request')
          expect(json_response['reviewers'].first['name']).to eq(user2.name)
        end

        it 'removes a reviewer from the existing merge request' do
          merge_request.reviewers = [user2]
          params[:reviewer_ids] = []

          put api("/projects/#{project.id}/merge_requests/#{merge_request.iid}", user), params: params

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response['title']).to eq('Updated merge request')
          expect(json_response['reviewers']).to be_empty
        end
      end

      context 'with merge_after' do
        let(:params) { { merge_after: '2025-01-09T20:47+0100' } }

        it 'sets merge_after on the MR' do
          put api("/projects/#{project.id}/merge_requests/#{merge_request.iid}", user), params: params

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response['merge_after']).to eq('2025-01-09T19:47:00.000Z')
        end

        context 'when the user is an assignee without permission to set merge request metadata' do
          let_it_be(:planner) { create(:user, planner_of: project) }

          before do
            merge_request.update!(assignees: [planner])
          end

          it 'ignores merge_after' do
            put api("/projects/#{project.id}/merge_requests/#{merge_request.iid}", planner),
              params: params.merge(title: 'Updated title')

            expect(response).to have_gitlab_http_status(:ok)
            expect(json_response['title']).to eq('Updated title')
            expect(json_response['merge_after']).to be_nil
          end
        end
      end

      context 'with oauth token that has ai_workflows scope' do
        let(:token) { create(:oauth_access_token, user: user, scopes: [:ai_workflows]) }

        it "allows access" do
          put api(
            "/projects/#{project.id}/merge_requests/#{merge_request.iid}?title=new_title",
            oauth_access_token: token
          )

          expect(response).to have_gitlab_http_status(:ok)
        end

        it "allows access to the project passed as a full path" do
          put api(
            "/projects/#{CGI.escape(project.full_path)}/merge_requests/#{merge_request.iid}?title=new_title",
            oauth_access_token: token
          )

          expect(response).to have_gitlab_http_status(:ok)
        end
      end

      context 'with composite identity', :request_store, :sidekiq_inline do
        let_it_be(:service_account) do
          create(:user, :service_account, composite_identity_enforced: true, developer_of: project)
        end

        context 'when human user assigns a service account as reviewer (web session)' do
          it 'attributes the system note to the human user' do
            put api("/projects/#{project.id}/merge_requests/#{merge_request.iid}", user),
              params: { reviewer_ids: [service_account.id] }

            expect(response).to have_gitlab_http_status(:ok)
            expect(merge_request.notes.system.last.author).to eq(user)
          end
        end

        context 'when human user assigns a service account as assignee (web session)' do
          it 'attributes the system note to the human user' do
            put api("/projects/#{project.id}/merge_requests/#{merge_request.iid}", user),
              params: { assignee_ids: [service_account.id] }

            expect(response).to have_gitlab_http_status(:ok)
            expect(merge_request.notes.system.last.author).to eq(user)
          end
        end

        context 'when service account acts via OAuth token (authentication context)' do
          before do
            ::Gitlab::Auth::Identity.new(service_account).link!(user, context: :authentication)
          end

          it 'attributes the system note to the service account' do
            put api("/projects/#{project.id}/merge_requests/#{merge_request.iid}", service_account),
              params: { title: 'Updated title' }

            expect(response).to have_gitlab_http_status(:ok)
            expect(merge_request.notes.system.last.author).to eq(service_account)
          end
        end
      end
    end

    context 'with remove_source_branch' do
      it 'sets to false' do
        merge_request.update!(merge_params: { 'force_remove_source_branch' => true })

        expect(merge_request.force_remove_source_branch?).to be_truthy

        put api("/projects/#{project.id}/merge_requests/#{merge_request.iid}", user),
          params: { state_event: "close", remove_source_branch: false }

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response['state']).to eq('closed')
        expect(json_response['force_remove_source_branch']).to be_falsey
      end

      it 'sets to true' do
        merge_request.update!(merge_params: { 'force_remove_source_branch' => false })

        expect(merge_request.force_remove_source_branch?).to be false

        put api("/projects/#{project.id}/merge_requests/#{merge_request.iid}", user),
          params: { state_event: "close", remove_source_branch: true }

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response['state']).to eq('closed')
        expect(json_response['force_remove_source_branch']).to be_truthy
      end

      context 'with a merge request across forks' do
        let(:project) do
          create(:project, :public, :repository, creator: user, namespace: user.namespace,
            only_allow_merge_if_pipeline_succeeds: false)
        end

        let(:fork_owner) { create(:user) }
        let(:source_project) { fork_project(project, fork_owner) }
        let(:target_project) { project }

        let(:merge_request) do
          create(
            :merge_request,
            source_project: source_project,
            target_project: target_project,
            source_branch: 'fixes',
            merge_params: { 'force_remove_source_branch' => false }
          )
        end

        it 'is true for an authorized user' do
          put api("/projects/#{target_project.id}/merge_requests/#{merge_request.iid}", fork_owner),
            params: { state_event: 'close', remove_source_branch: true }

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response['state']).to eq('closed')
          expect(json_response['force_remove_source_branch']).to be true
        end

        it 'is false for an unauthorized user' do
          expect do
            put api("/projects/#{target_project.id}/merge_requests/#{merge_request.iid}", target_project.first_owner),
              params: { state_event: 'close', remove_source_branch: true }
          end.not_to change { merge_request.reload.merge_params }

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response['state']).to eq('closed')
          expect(json_response['force_remove_source_branch']).to be false
        end
      end
    end

    context "when reopening a merge request" do
      let(:merge_request) do
        create(:merge_request, :closed, author: user, assignees: [user], source_project: project,
          target_project: project, source_branch: 'markdown')
      end

      it "reopens the merge request" do
        put api("/projects/#{project.id}/merge_requests/#{merge_request.iid}", user), params: { state_event: "reopen" }

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response['state']).to eq('opened')
      end

      context "when the source branch no longer exists" do
        let(:merge_request) do
          create(:merge_request, :closed, author: user, assignees: [user], source_project: project,
            target_project: project, source_branch: 'this-source-branch-does-not-exist')
        end

        let(:branch_error) do
          'Cannot reopen this merge request because the source or target branch no longer exists.'
        end

        it "does not reopen the merge request and returns an error" do
          put api("/projects/#{project.id}/merge_requests/#{merge_request.iid}", user),
            params: { state_event: "reopen" }

          expect(response).to have_gitlab_http_status(:unprocessable_entity)
          expect(json_response['message']).to include(branch_error)
        end

        it "does not apply other changes in the same request" do
          put api("/projects/#{project.id}/merge_requests/#{merge_request.iid}", user),
            params: { state_event: "reopen", title: "A brand new title" }

          expect(response).to have_gitlab_http_status(:unprocessable_entity)
          expect(merge_request.reload).to be_closed
          expect(merge_request.title).not_to eq("A brand new title")
        end
      end
    end

    it "updates title and returns merge_request" do
      put api("/projects/#{project.id}/merge_requests/#{merge_request.iid}", user), params: { title: "New title" }
      expect(response).to have_gitlab_http_status(:ok)
      expect(json_response['title']).to eq('New title')
    end

    it "updates description and returns merge_request" do
      put api("/projects/#{project.id}/merge_requests/#{merge_request.iid}", user),
        params: { description: "New description" }
      expect(response).to have_gitlab_http_status(:ok)
      expect(json_response['description']).to eq('New description')
    end

    it "updates milestone_id and returns merge_request" do
      put api("/projects/#{project.id}/merge_requests/#{merge_request.iid}", user),
        params: { milestone_id: milestone.id }
      expect(response).to have_gitlab_http_status(:ok)
      expect(json_response['milestone']['id']).to eq(milestone.id)
    end

    it "leaves the milestone unchanged when milestone_id is invalid" do
      put api("/projects/#{project.id}/merge_requests/#{merge_request.iid}", user),
        params: { milestone_id: non_existing_record_id }

      expect(response).to have_gitlab_http_status(:ok)
      expect(json_response['milestone']).to be_nil
    end

    it "updates milestone via title and returns merge_request" do
      put api("/projects/#{project.id}/merge_requests/#{merge_request.iid}", user),
        params: { milestone: milestone.title }

      expect(response).to have_gitlab_http_status(:ok)
      expect(json_response['milestone']['id']).to eq(milestone.id)
    end

    it "leaves the milestone unchanged when the milestone title does not match any milestone in scope" do
      put api("/projects/#{project.id}/merge_requests/#{merge_request.iid}", user),
        params: { milestone: 'nonexistent' }

      expect(response).to have_gitlab_http_status(:ok)
      expect(json_response['milestone']).to be_nil
    end

    it "returns 400 when both milestone and milestone_id are provided" do
      put api("/projects/#{project.id}/merge_requests/#{merge_request.iid}", user),
        params: { milestone: milestone.title, milestone_id: milestone.id }

      expect(response).to have_gitlab_http_status(:bad_request)
    end

    it "returns 400 when milestone title exceeds the length limit" do
      put api("/projects/#{project.id}/merge_requests/#{merge_request.iid}", user),
        params: { milestone: 'a' * 256 }

      expect(response).to have_gitlab_http_status(:bad_request)
      expect(json_response['error']).to include('milestone must be less than 255 characters')
    end

    it "updates squash and returns merge_request" do
      put api("/projects/#{project.id}/merge_requests/#{merge_request.iid}", user), params: { squash: true }

      expect(response).to have_gitlab_http_status(:ok)
      expect(json_response['squash']).to be_truthy
    end

    it "updates target_branch and returns merge_request" do
      put api("/projects/#{project.id}/merge_requests/#{merge_request.iid}", user), params: { target_branch: "wiki" }
      expect(response).to have_gitlab_http_status(:ok)
      expect(json_response['target_branch']).to eq('wiki')
    end

    it_behaves_like 'authorizing granular token permissions', :update_merge_request do
      let(:boundary_object) { project }
      let(:request) do
        put api("/projects/#{project.id}/merge_requests/#{merge_request.iid}", personal_access_token: pat),
          params: { title: 'New title' }
      end
    end

    context "with forked projects" do
      let_it_be(:user2, freeze: false) { create(:user) }

      let(:project) { create(:project, :public, :repository) }
      let!(:forked_project) { fork_project(project, user2, repository: true) }
      let(:merge_request) do
        create(
          :merge_request,
          source_project: forked_project,
          target_project: project,
          source_branch: "fixes"
        )
      end

      shared_examples "update of allow_collaboration and allow_maintainer_to_push" do |request_value, expected_value|
        it "updates with either param to #{request_value} and returns #{expected_value} for `allow_collaboration`" do
          %w[allow_collaboration allow_maintainer_to_push].each do |attr|
            merge_request.update_column(:allow_maintainer_to_push, !request_value)

            put api("/projects/#{project.id}/merge_requests/#{merge_request.iid}", user2),
              params: { attr => request_value }

            expect(response).to have_gitlab_http_status(:ok)
            expect(json_response["allow_collaboration"]).to eq(expected_value)
            expect(json_response["allow_maintainer_to_push"]).to eq(expected_value)
          end
        end
      end

      context "when source project is public (i.e. MergeRequest#collaborative_push_possible? == true)" do
        it_behaves_like "update of allow_collaboration and allow_maintainer_to_push", true, true
      end

      context "when source project is private (i.e. MergeRequest#collaborative_push_possible? == false)" do
        let(:project) { create(:project, :private, :repository, reporters: user2) }

        it_behaves_like "update of allow_collaboration and allow_maintainer_to_push", true, false
      end
    end

    context 'when updating labels' do
      it 'allows special label names' do
        put api("/projects/#{project.id}/merge_requests/#{merge_request.iid}", user),
          params: {
            title: 'new issue',
            labels: 'label, label?, label&foo, ?, &'
          }

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response['labels']).to include 'label'
        expect(json_response['labels']).to include 'label?'
        expect(json_response['labels']).to include 'label&foo'
        expect(json_response['labels']).to include '?'
        expect(json_response['labels']).to include '&'
      end

      it 'empty label param removes labels' do
        put api("/projects/#{project.id}/merge_requests/#{merge_request.iid}", user),
          params: {
            title: 'new issue',
            labels: ''
          }

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response['labels']).to eq []
      end

      it 'label param as empty array, but only explicitly as json, removes labels' do
        put api("/projects/#{project.id}/merge_requests/#{merge_request.iid}", user),
          params: {
            title: 'new issue',
            labels: []
          }.to_json,
          headers: { 'Content-Type' => 'application/json' }

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response['labels']).to eq []
      end

      it 'empty label as array, removes labels' do
        put api("/projects/#{project.id}/merge_requests/#{merge_request.iid}", user),
          params: {
            title: 'new issue',
            labels: []
          }

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response['labels']).to eq []
      end

      it 'array with one empty string element removes labels' do
        put api("/projects/#{project.id}/merge_requests/#{merge_request.iid}", user),
          params: {
            title: 'new issue',
            labels: ['']
          }

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response['labels']).to eq []
      end

      it 'array with multiple empty string elements, removes labels' do
        put api("/projects/#{project.id}/merge_requests/#{merge_request.iid}", user),
          params: {
            title: 'new issue',
            labels: ['', '', '']
          }

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response['labels']).to eq []
      end
    end

    context 'with labels' do
      include_context 'with labels'

      let(:api_base) { api("/projects/#{project.id}/merge_requests/#{merge_request.iid}", user) }

      it 'when adding labels, keeps existing labels and adds new' do
        put api_base, params: { add_labels: '1, 2' }

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response['labels']).to contain_exactly(label.title, label2.title, '1', '2')
      end

      it 'when removing labels, only removes those specified' do
        put api_base, params: { remove_labels: label.title.to_s }

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response['labels']).to eq([label2.title])
      end

      it 'when removing all labels, keeps no labels' do
        put api_base, params: { remove_labels: "#{label.title}, #{label2.title}" }

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response['labels']).to be_empty
      end
    end

    it 'does not update state when title is empty' do
      put api("/projects/#{project.id}/merge_requests/#{merge_request.iid}", user),
        params: { state_event: 'close', title: nil }

      merge_request.reload
      expect(response).to have_gitlab_http_status(:bad_request)
      expect(merge_request.state).to eq('opened')
    end

    it 'does not update state when target_branch is empty' do
      put api("/projects/#{project.id}/merge_requests/#{merge_request.iid}", user),
        params: { state_event: 'close', target_branch: nil }

      merge_request.reload
      expect(response).to have_gitlab_http_status(:bad_request)
      expect(merge_request.state).to eq('opened')
    end

    it "returns 404 for an invalid merge request IID" do
      put api("/projects/#{project.id}/merge_requests/#{non_existing_record_iid}", user),
        params: { state_event: "close" }

      expect(response).to have_gitlab_http_status(:not_found)
    end

    it "returns 404 if the merge request id is used instead of iid" do
      put api("/projects/#{project.id}/merge_requests/#{merge_request_id_not_used_as_iid}", user),
        params: { state_event: "close" }

      expect(response).to have_gitlab_http_status(:not_found)
    end
  end

  describe "DELETE /projects/:id/merge_requests/:merge_request_iid" do
    include_context 'with a merge request created once'

    context "when the user is developer" do
      let(:developer) { create(:user) }

      before do
        project.add_developer(developer)
      end

      it "denies the deletion of the merge request" do
        delete api("/projects/#{project.id}/merge_requests/#{merge_request.iid}", developer)
        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end

    context "when the user is project owner" do
      it "returns 404 for an invalid merge request IID" do
        delete api("/projects/#{project.id}/merge_requests/#{non_existing_record_iid}", user)

        expect(response).to have_gitlab_http_status(:not_found)
      end

      it "returns 404 if the merge request id is used instead of iid" do
        delete api("/projects/#{project.id}/merge_requests/#{merge_request_id_not_used_as_iid}", user)

        expect(response).to have_gitlab_http_status(:not_found)
      end

      it_behaves_like '412 response' do
        let(:request) { api("/projects/#{project.id}/merge_requests/#{merge_request.iid}", user) }
      end
    end

    it_behaves_like 'authorizing granular token permissions', :delete_merge_request do
      let(:boundary_object) { project }
      let(:request) do
        delete api("/projects/#{project.id}/merge_requests/#{merge_request.iid}", personal_access_token: pat)
      end
    end
  end

  describe 'POST :id/merge_requests/:merge_request_iid/subscribe' do
    include_context 'with a merge request created once'

    it_behaves_like 'POST request permissions for admin mode' do
      let(:path) { "/projects/#{project.id}/merge_requests/#{merge_request.iid}/subscribe" }
      let(:params) { {} }
    end

    it_behaves_like 'authorizing granular token permissions', :subscribe_merge_request,
      expected_success_status: :not_modified do
      let(:boundary_object) { project }
      let(:request) do
        post api("/projects/#{project.id}/merge_requests/#{merge_request.iid}/subscribe", personal_access_token: pat)
      end
    end

    it 'subscribes to a merge request' do
      post api("/projects/#{project.id}/merge_requests/#{merge_request.iid}/subscribe", admin, admin_mode: true)

      expect(response).to have_gitlab_http_status(:created)
      expect(json_response['subscribed']).to be(true)
    end

    it 'returns 304 if already subscribed' do
      post api("/projects/#{project.id}/merge_requests/#{merge_request.iid}/subscribe", user)

      expect(response).to have_gitlab_http_status(:not_modified)
    end

    it 'returns 404 if the merge request is not found' do
      post api("/projects/#{project.id}/merge_requests/#{non_existing_record_iid}/subscribe", user)

      expect(response).to have_gitlab_http_status(:not_found)
    end

    it 'returns 404 if the merge request id is used instead of iid' do
      post api("/projects/#{project.id}/merge_requests/#{merge_request_id_not_used_as_iid}/subscribe", user)

      expect(response).to have_gitlab_http_status(:not_found)
    end

    it 'returns 403 if user has no access to read code' do
      guest = create(:user)
      project.add_guest(guest)

      post api("/projects/#{project.id}/merge_requests/#{merge_request.iid}/subscribe", guest)

      expect(response).to have_gitlab_http_status(:forbidden)
    end
  end

  describe 'POST :id/merge_requests/:merge_request_iid/unsubscribe' do
    include_context 'with a merge request created once'

    it_behaves_like 'authorizing granular token permissions', :subscribe_merge_request do
      let(:boundary_object) { project }
      let(:request) do
        post api("/projects/#{project.id}/merge_requests/#{merge_request.iid}/unsubscribe", personal_access_token: pat)
      end
    end

    it 'unsubscribes from a merge request' do
      post api("/projects/#{project.id}/merge_requests/#{merge_request.iid}/unsubscribe", user)

      expect(response).to have_gitlab_http_status(:created)
      expect(json_response['subscribed']).to be(false)
    end

    it 'returns 304 if not subscribed' do
      post api("/projects/#{project.id}/merge_requests/#{merge_request.iid}/unsubscribe", admin, admin_mode: true)

      expect(response).to have_gitlab_http_status(:not_modified)
    end

    it 'returns 404 if the merge request is not found' do
      post api("/projects/#{project.id}/merge_requests/#{non_existing_record_iid}/unsubscribe", user)

      expect(response).to have_gitlab_http_status(:not_found)
    end

    it 'returns 404 if the merge request id is used instead of iid' do
      post api("/projects/#{project.id}/merge_requests/#{merge_request_id_not_used_as_iid}/unsubscribe", user)

      expect(response).to have_gitlab_http_status(:not_found)
    end

    it 'returns 403 if user has no access to read code' do
      guest = create(:user)
      project.add_guest(guest)

      post api("/projects/#{project.id}/merge_requests/#{merge_request.iid}/unsubscribe", guest)

      expect(response).to have_gitlab_http_status(:forbidden)
    end
  end

  describe 'Time tracking' do
    let_it_be_with_refind(:issuable) do
      create(:merge_request, :simple, author: user, assignees: [user], source_project: project, target_project: project,
        source_branch: 'markdown', title: "Test", created_at: base_time)
    end

    include_examples 'time tracking endpoints', 'merge_request'
  end
end
