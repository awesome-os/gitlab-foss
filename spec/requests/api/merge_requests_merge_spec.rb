# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::MergeRequests, :aggregate_failures, feature_category: :source_code_management do
  include_context 'with merge requests API setup'

  shared_examples 'merging with auto merge strategies' do
    context 'when only_allow_merge_if_pipeline_succeeds is true' do
      before do
        project.update_attribute(:only_allow_merge_if_pipeline_succeeds, true)
      end

      it 'sets auto merge when the pipeline has failed' do
        create(:ci_pipeline,
          :failed,
          sha: merge_request.diff_head_sha,
          merge_requests_as_head_pipeline: [merge_request])

        put api("/projects/#{project.id}/merge_requests/#{merge_request.iid}/merge", user), params: params

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response['merge_when_pipeline_succeeds']).to be(true)
        expect(merge_request.reload.state).to eq('opened')
      end

      it "sets auto merge when the pipeline is active" do
        allow_next_found_instance_of(MergeRequest) do |merge_request|
          allow(merge_request).to receive_messages(head_pipeline: pipeline, diff_head_pipeline: pipeline)
        end
        allow(pipeline).to receive(:active?).and_return(true)

        put api("/projects/#{project.id}/merge_requests/#{merge_request.iid}/merge", user), params: params

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response['title']).to eq('Test')
        expect(json_response['merge_when_pipeline_succeeds']).to be(true)
      end

      it 'merges when the pipeline succeeds' do
        create(:ci_pipeline, :success, sha: merge_request.diff_head_sha,
          merge_requests_as_head_pipeline: [merge_request])

        put api("/projects/#{project.id}/merge_requests/#{merge_request.iid}/merge", user), params: params

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response['state']).to eq('merged')
      end

      it 'sets auto merge when no pipeline exists' do
        put api("/projects/#{project.id}/merge_requests/#{merge_request.iid}/merge", user), params: params

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response['merge_when_pipeline_succeeds']).to be(true)
        expect(merge_request.reload.state).to eq('opened')
      end

      it 'returns 422 when the pipeline succeeds but merge fails' do
        create(:ci_pipeline, :success, sha: merge_request.diff_head_sha,
          merge_requests_as_head_pipeline: [merge_request])

        allow_next_instance_of(AutoMergeService) do |service|
          allow(service).to receive(:available_strategies).and_return([])
        end

        allow_next_instance_of(::MergeRequests::MergeService) do |service|
          allow(service).to receive(:execute)
        end

        put api("/projects/#{project.id}/merge_requests/#{merge_request.iid}/merge", user), params: params

        expect(response).to have_gitlab_http_status(:unprocessable_entity)
        expect(json_response['message']).to eq('Branch cannot be merged')
      end
    end

    context 'when only_allow_merge_if_pipeline_succeeds is false' do
      before do
        project.update_attribute(:only_allow_merge_if_pipeline_succeeds, false)
      end

      it "returns 422 if branch can't be merged due to mergeability check" do
        create(:ci_pipeline, :success, sha: merge_request.diff_head_sha,
          merge_requests_as_head_pipeline: [merge_request])

        allow_next_instance_of(AutoMergeService) do |service|
          allow(service).to receive(:available_strategies).and_return([])
        end

        allow_next_found_instance_of(MergeRequest) do |merge_request|
          allow(merge_request).to receive(:mergeable?).and_return(false)
        end

        put api("/projects/#{project.id}/merge_requests/#{merge_request.iid}/merge", user), params: params

        expect(response).to have_gitlab_http_status(:unprocessable_entity)
        expect(json_response['message']).to eq('Branch cannot be merged')
      end

      it 'returns not allowed when the pipeline has failed' do
        create(:ci_pipeline,
          :failed,
          sha: merge_request.diff_head_sha,
          merge_requests_as_head_pipeline: [merge_request])

        put api("/projects/#{project.id}/merge_requests/#{merge_request.iid}/merge", user), params: params

        expect(response).to have_gitlab_http_status(:method_not_allowed)
      end

      context 'when no pipeline exists' do
        it 'merges immediately' do
          put api("/projects/#{project.id}/merge_requests/#{merge_request.iid}/merge", user), params: params

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response['state']).to eq('merged')
        end
      end

      context 'when no pipeline exists but one is being created' do
        before do
          allow_next_found_instance_of(MergeRequest) do |mr|
            allow(mr).to receive(:pipeline_creating?).and_return(true)
          end
        end

        it 'sets auto merge' do
          put api("/projects/#{project.id}/merge_requests/#{merge_request.iid}/merge", user), params: params

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response['merge_when_pipeline_succeeds']).to be(true)
          expect(merge_request.reload.state).to eq('opened')
        end
      end

      it "sets auto merge when the pipeline is active" do
        allow_next_found_instance_of(MergeRequest) do |merge_request|
          allow(merge_request).to receive_messages(head_pipeline: pipeline, diff_head_pipeline: pipeline)
        end
        allow(pipeline).to receive(:active?).and_return(true)

        put api("/projects/#{project.id}/merge_requests/#{merge_request.iid}/merge", user), params: params

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response['title']).to eq('Test')
        expect(json_response['state']).to eq('opened')
        expect(json_response['merge_when_pipeline_succeeds']).to be(true)
      end
    end
  end

  describe "PUT /projects/:id/merge_requests/:merge_request_iid/merge", :clean_gitlab_redis_cache do
    let(:project) { create(:project, :repository, namespace: user.namespace) }
    let(:merge_request) do
      create(:merge_request, :simple, author: user, source_project: project, source_branch: 'markdown', title: 'Test')
    end

    let(:pipeline) { create(:ci_pipeline, project: project) }

    context 'with oauth token that has ai_workflows scope' do
      let(:token) { create(:oauth_access_token, user: user, scopes: [:ai_workflows]) }

      it "does not allow access" do
        put api("/projects/#{project.id}/merge_requests/#{merge_request.iid}/merge", oauth_access_token: token)

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end

    it_behaves_like 'authorizing granular token permissions', :merge_merge_request do
      let(:boundary_object) { project }
      let(:request) do
        put api("/projects/#{project.id}/merge_requests/#{merge_request.iid}/merge", personal_access_token: pat)
      end
    end

    it "returns merge_request in case of success" do
      expect { put api("/projects/#{project.id}/merge_requests/#{merge_request.iid}/merge", user) }
        .to change { merge_request.reload.merged? }
        .from(false)
        .to(true)

      expect(response).to have_gitlab_http_status(:ok)
    end

    context 'when the merge request fails to merge' do
      it 'returns 422' do
        expect_next_instance_of(::MergeRequests::MergeService) do |service|
          expect(service).to receive(:execute)
        end

        expect { put api("/projects/#{project.id}/merge_requests/#{merge_request.iid}/merge", user) }
          .not_to change { merge_request.reload.merged? }

        expect(response).to have_gitlab_http_status(:unprocessable_entity)
        expect(json_response['message']).to eq("Branch cannot be merged")
      end
    end

    it "returns 405 if branch can't be merged" do
      allow_next_found_instance_of(MergeRequest) do |merge_request|
        allow(merge_request).to receive(:mergeable?).and_return(false)
      end

      put api("/projects/#{project.id}/merge_requests/#{merge_request.iid}/merge", user)

      expect(response).to have_gitlab_http_status(:method_not_allowed)
      expect(json_response['message']).to eq('405 Method Not Allowed')
    end

    it 'returns 405 if the build failed for a merge request that requires success' do
      project.update!(only_allow_merge_if_pipeline_succeeds: true)

      create(
        :ci_pipeline,
        :failed,
        sha: merge_request.diff_head_sha,
        merge_requests_as_head_pipeline: [merge_request]
      )

      put api("/projects/#{project.id}/merge_requests/#{merge_request.iid}/merge", user)

      expect(response).to have_gitlab_http_status(:method_not_allowed)
      expect(json_response['message']).to eq('405 Method Not Allowed')
    end

    it "returns 401 if user has no permissions to merge" do
      user2 = create(:user)
      project.add_reporter(user2)
      put api("/projects/#{project.id}/merge_requests/#{merge_request.iid}/merge", user2)
      expect(response).to have_gitlab_http_status(:unauthorized)
      expect(json_response['message']).to eq('401 Unauthorized')
    end

    it "returns 409 if the SHA parameter doesn't match" do
      put api("/projects/#{project.id}/merge_requests/#{merge_request.iid}/merge", user),
        params: { sha: merge_request.diff_head_sha.reverse }

      expect(response).to have_gitlab_http_status(:conflict)
      expect(json_response['message']).to start_with('SHA does not match HEAD of source branch')
    end

    shared_examples 'enforces presence of SHA parameter' do
      it 'returns 400 when sha param is not provided' do
        put api("/projects/#{project.id}/merge_requests/#{merge_request.iid}/merge", user)

        expect(response).to have_gitlab_http_status(:bad_request)
        expect(json_response['message']).to eq('SHA must be provided when merging')
      end

      it 'proceeds with merge when sha param is provided' do
        put api("/projects/#{project.id}/merge_requests/#{merge_request.iid}/merge", user),
          params: { sha: merge_request.diff_head_sha }

        expect(response).to have_gitlab_http_status(:ok)
      end
    end

    context 'when a namespace requires SHA for merge' do
      before do
        project.namespace.namespace_settings.update!(require_sha_for_merge: true)
      end

      it_behaves_like 'enforces presence of SHA parameter'
    end

    context 'when the new auto_merge param is used' do
      let(:params) { { auto_merge: true } }

      it_behaves_like 'merging with auto merge strategies'
    end

    context 'when the MR is still preparing and a pipeline is being created', :clean_gitlab_redis_shared_state do
      # Reproduces the transient state right after POST /merge_requests, where the MR is
      # preparing (diffs not computed) and a pipeline is being created.
      # See https://gitlab.com/gitlab-org/gitlab/-/work_items/473054
      before do
        merge_request.mark_as_preparing!
        Ci::PipelineCreation::Requests.start_for_merge_request(merge_request)
      end

      it 'sets auto merge instead of returning 405' do
        put api("/projects/#{project.id}/merge_requests/#{merge_request.iid}/merge", user),
          params: { auto_merge: true }

        expect(response).to have_gitlab_http_status(:ok)
        expect(merge_request.reload.auto_merge_enabled).to be(true)
        expect(merge_request.auto_merge_strategy).to eq(AutoMergeService::STRATEGY_MERGE_WHEN_CHECKS_PASS)
      end
    end

    context 'when the MR is still preparing and its diff has not been created yet' do
      # Reproduces the window between POST /merge_requests returning and NewMergeRequestWorker
      # writing the diff. See https://gitlab.com/gitlab-org/cli/-/work_items/8140
      let(:merge_request) do
        create(:merge_request, :simple, :skip_diff_creation, author: user, source_project: project,
          source_branch: 'markdown', title: 'Test')
      end

      before do
        merge_request.mark_as_preparing!
      end

      it 'sets auto merge instead of returning 422' do
        expect(merge_request.has_no_commits?).to be(true)

        put api("/projects/#{project.id}/merge_requests/#{merge_request.iid}/merge", user),
          params: { auto_merge: true }

        expect(response).to have_gitlab_http_status(:ok)
        expect(merge_request.reload.auto_merge_enabled).to be(true)
        expect(merge_request.auto_merge_strategy).to eq(AutoMergeService::STRATEGY_MERGE_WHEN_CHECKS_PASS)
      end
    end

    it 'enables auto merge if the MR is not mergeable and only_allow_merge_if_pipeline_succeeds is true' do
      allow_next_found_instance_of(MergeRequest) do |merge_request|
        allow(merge_request).to receive_messages(head_pipeline: pipeline, diff_head_pipeline: pipeline)
      end

      merge_request.update!(title: 'Draft: 1234')

      project.update_attribute(:only_allow_merge_if_pipeline_succeeds, true)

      put api("/projects/#{project.id}/merge_requests/#{merge_request.iid}/merge", user),
        params: { merge_when_pipeline_succeeds: true }

      expect(response).to have_gitlab_http_status(:ok)
      expect(json_response['title']).to eq('Draft: 1234')
      expect(json_response['merge_when_pipeline_succeeds']).to be(true)
    end

    context 'when auto merge is already enabled' do
      before do
        create(:ci_pipeline, :running, sha: merge_request.diff_head_sha,
          merge_requests_as_head_pipeline: [merge_request])

        put api("/projects/#{project.id}/merge_requests/#{merge_request.iid}/merge", user), params: { auto_merge: true }
      end

      it 'updates the merge params without processing auto merge again' do
        expect(AutoMergeProcessWorker).not_to receive(:perform_async)

        put api("/projects/#{project.id}/merge_requests/#{merge_request.iid}/merge", user),
          params: { auto_merge: true, merge_commit_message: 'Updated message' }

        expect(response).to have_gitlab_http_status(:ok)
        expect(merge_request.reload.merge_params['commit_message']).to eq('Updated message')
      end
    end

    context 'when the pipeline failed' do
      let(:pipeline) { create(:ci_pipeline, :failed, project: project) }

      it "enables auto merge if the pipeline is failed and only_allow_merge_if_pipeline_succeeds is true" do
        allow_next_found_instance_of(MergeRequest) do |merge_request|
          allow(merge_request).to receive_messages(head_pipeline: pipeline, diff_head_pipeline: pipeline)
        end
        project.update_attribute(:only_allow_merge_if_pipeline_succeeds, true)

        put api("/projects/#{project.id}/merge_requests/#{merge_request.iid}/merge", user),
          params: { merge_when_pipeline_succeeds: true }

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response['title']).to eq('Test')
        expect(json_response['merge_when_pipeline_succeeds']).to be(true)
      end
    end

    it "returns 404 for an invalid merge request IID" do
      put api("/projects/#{project.id}/merge_requests/#{non_existing_record_iid}/merge", user)

      expect(response).to have_gitlab_http_status(:not_found)
    end

    it "returns 404 if the merge request id is used instead of iid" do
      put api("/projects/#{project.id}/merge_requests/#{merge_request_id_not_used_as_iid}/merge", user)

      expect(response).to have_gitlab_http_status(:not_found)
    end

    describe "the squash_commit_message param" do
      let(:squash_commit) do
        project.repository.commits_between(json_response['diff_refs']['start_sha'],
          json_response['merge_commit_sha']).first
      end

      it "results in a specific squash commit message when set" do
        squash_commit_message = 'My custom squash commit message'

        put api("/projects/#{project.id}/merge_requests/#{merge_request.iid}/merge", user), params: {
          squash: true,
          squash_commit_message: squash_commit_message
        }

        expect(response).to have_gitlab_http_status(:ok)
        expect(squash_commit.message.chomp).to eq(squash_commit_message)
      end

      it "results in a default squash commit message when not set" do
        put api("/projects/#{project.id}/merge_requests/#{merge_request.iid}/merge", user), params: { squash: true }

        expect(response).to have_gitlab_http_status(:ok)
        expect(merge_request.reload.squash_on_merge?).to be(true)
        expect(squash_commit.message.chomp).to eq(merge_request.default_squash_commit_message.chomp)
      end

      context 'when squash_commit_message is empty' do
        it 'uses a default squash commit message' do
          put api("/projects/#{project.id}/merge_requests/#{merge_request.iid}/merge", user),
            params: { squash: true, squash_commit_message: '' }

          expect(response).to have_gitlab_http_status(:ok)
          expect(squash_commit.message.chomp).to eq(merge_request.default_squash_commit_message.chomp)
        end
      end

      context 'when a squash commit message was saved with auto-merge' do
        let(:saved_message) { 'Saved with auto-merge' }
        let(:merge_path) { api("/projects/#{project.id}/merge_requests/#{merge_request.iid}/merge", user) }
        let(:committed_squash_message) do
          project.commit(merge_request.reload.squash_commit_sha).message.chomp
        end

        let!(:pipeline) do
          create(:ci_pipeline, :running, project: project, sha: merge_request.diff_head_sha,
            merge_requests_as_head_pipeline: [merge_request])
        end

        before do
          project.update!(only_allow_merge_if_pipeline_succeeds: true)

          put merge_path, params: { auto_merge: true, squash: true, squash_commit_message: saved_message }
        end

        it 'saves the message and rejects an immediate merge while the pipeline is running' do
          expect(merge_request.reload.merge_params['squash_commit_message']).to eq(saved_message)

          put merge_path

          expect(response).to have_gitlab_http_status(:method_not_allowed)
          expect(merge_request.reload).to be_opened
          expect(merge_request.auto_merge_enabled).to be(true)
        end

        context 'when the pipeline succeeds before auto-merge is processed' do
          before do
            pipeline.succeed!
          end

          it 'commits the default message when the request sends none' do
            put merge_path

            expect(response).to have_gitlab_http_status(:ok)
            expect(committed_squash_message).to eq(merge_request.default_squash_commit_message.chomp)
          end

          it 'commits the message from the request' do
            put merge_path, params: { squash_commit_message: 'Sent with the merge request' }

            expect(response).to have_gitlab_http_status(:ok)
            expect(committed_squash_message).to eq('Sent with the merge request')
          end
        end
      end
    end

    describe "the should_remove_source_branch param", :sidekiq_inline do
      let(:source_repository) { merge_request.source_project.repository }
      let(:source_branch) { merge_request.source_branch }

      it 'removes the source branch when set' do
        put(
          api("/projects/#{project.id}/merge_requests/#{merge_request.iid}/merge", user),
          params: { should_remove_source_branch: true }
        )

        expect(response).to have_gitlab_http_status(:ok)
        expect(source_repository.branch_exists?(source_branch)).to be false
        expect(merge_request.reload.should_remove_source_branch?).to be true
      end
    end

    context "with a merge request that has force_remove_source_branch enabled", :sidekiq_inline do
      let(:source_repository) { merge_request.source_project.repository }
      let(:source_branch) { merge_request.source_branch }

      before do
        merge_request.update!(merge_params: { 'force_remove_source_branch' => true })
      end

      it 'removes the source branch' do
        put(
          api("/projects/#{project.id}/merge_requests/#{merge_request.iid}/merge", user)
        )

        expect(response).to have_gitlab_http_status(:ok)
        expect(source_repository.branch_exists?(source_branch)).to be false
        expect(merge_request.reload.should_remove_source_branch?).to be_nil
      end

      it 'does not remove the source branch' do
        put(
          api("/projects/#{project.id}/merge_requests/#{merge_request.iid}/merge", user),
          params: { should_remove_source_branch: false }
        )

        expect(response).to have_gitlab_http_status(:ok)
        expect(source_repository.branch_exists?(source_branch)).to be_truthy
        expect(merge_request.reload.should_remove_source_branch?).to be false
      end
    end

    context "when performing a fast-forward merge with squash" do
      let(:merge_request) { create(:merge_request, :rebased, source_project: project, squash: true) }

      before do
        project.update!(merge_requests_ff_only_enabled: true)
      end

      it "records the squash commit SHA and returns it in the response" do
        put api("/projects/#{project.id}/merge_requests/#{merge_request.iid}/merge", user)

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response['squash_commit_sha'].length).to eq(40)
      end
    end
  end

  describe "GET /projects/:id/merge_requests/:merge_request_iid/merge_ref", :clean_gitlab_redis_shared_state do
    before do
      merge_request.mark_as_unchecked!
    end

    let(:merge_request_iid) { merge_request.iid }

    let(:url) do
      "/projects/#{project.id}/merge_requests/#{merge_request_iid}/merge_ref"
    end

    it 'returns the generated ID from the merge service in case of success' do
      get api(url, user)

      expect(response).to have_gitlab_http_status(:ok)
      expect(json_response['commit_id']).to eq(merge_request.merge_ref_head.sha)
    end

    context 'when merge-ref is not synced with merge status' do
      let_it_be_with_reload(:merge_request) do
        create(:merge_request, :simple, author: user, source_project: project, source_branch: 'markdown',
          merge_status: 'cannot_be_merged')
      end

      it 'returns 200 if MR can be merged' do
        get api(url, user)

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response['commit_id']).to eq(merge_request.merge_ref_head.sha)
      end

      it 'returns 400 if MR cannot be merged' do
        expect_next_instance_of(MergeRequests::MergeToRefService) do |merge_request|
          expect(merge_request).to receive(:execute).and_return({ status: :failed })
        end

        get api(url, user)

        expect(response).to have_gitlab_http_status(:bad_request)
        expect(json_response['message']).to eq('Merge request is not mergeable')
      end
    end

    context 'when user has no access to the MR' do
      let(:project) { create(:project, :private) }
      let(:merge_request) { create(:merge_request, source_project: project, target_project: project) }

      it 'returns 404' do
        project.add_guest(user)

        get api(url, user)

        expect(response).to have_gitlab_http_status(:not_found)
        expect(json_response['message']).to eq('404 Not found')
      end
    end

    context 'when invalid merge request IID' do
      let(:merge_request_iid) { non_existing_record_iid }

      it 'returns 404' do
        get api(url, user)

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context 'when merge request ID is used instead IID' do
      let(:merge_request_iid) { merge_request_id_not_used_as_iid }

      it 'returns 404' do
        get api(url, user)

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context 'with the merge ref rate limit', :clean_gitlab_redis_rate_limiting do
      before do
        stub_application_setting(merge_requests_merge_ref_limit: 1)
      end

      it 'rate limits each user before the mergeability check', :aggregate_failures do
        expect(MergeRequests::MergeabilityCheckService).to receive(:new).twice.and_call_original

        get api(url, user)

        expect(response).to have_gitlab_http_status(:ok)

        get api(url, user)

        expect(response).to have_gitlab_http_status(:too_many_requests)
        expect(response.headers['RateLimit-Name']).to eq('merge_requests_merge_ref')

        get api(url, user2)

        expect(response).to have_gitlab_http_status(:ok)
      end

      it 'rate limits an anonymous request by IP address' do
        get api(url)
        get api(url)

        expect(response).to have_gitlab_http_status(:too_many_requests)
      end
    end

    it_behaves_like 'authorizing granular token permissions', :read_merge_request_merge_ref do
      let(:boundary_object) { project }
      let(:request) do
        get api("/projects/#{project.id}/merge_requests/#{merge_request.iid}/merge_ref", personal_access_token: pat)
      end
    end
  end

  describe 'POST :id/merge_requests/:merge_request_iid/cancel_merge_when_pipeline_succeeds' do
    context 'when an auto-merge is set' do
      let(:merge_request) do
        create(:merge_request, :simple, :merge_when_checks_pass, author: user, assignees: [user],
          source_project: project, target_project: project, source_branch: 'markdown', title: 'Test')
      end

      it 'answers 201 with a success status and cancels the auto-merge' do
        post api("/projects/#{project.id}/merge_requests/#{merge_request.iid}/cancel_merge_when_pipeline_succeeds",
          user)

        expect(response).to have_gitlab_http_status(:created)
        expect(json_response).to eq('status' => 'success')
        expect(merge_request.reload.auto_merge_enabled).to be(false)
      end
    end

    context 'when no auto-merge is set' do
      it 'answers 201 with an error status, not 406' do
        merge_request.update!(auto_merge_enabled: false)

        post api("/projects/#{project.id}/merge_requests/#{merge_request.iid}/cancel_merge_when_pipeline_succeeds",
          user)

        expect(response).to have_gitlab_http_status(:created)
        expect(json_response).to eq(
          'message' => "Can't cancel the automatic merge",
          'status' => 'error',
          'http_status' => 406
        )
      end
    end

    it 'returns 404 if the merge request is not found' do
      post api(
        "/projects/#{project.id}/merge_requests/#{non_existing_record_iid}/cancel_merge_when_pipeline_succeeds", user
      )

      expect(response).to have_gitlab_http_status(:not_found)
    end

    it 'returns 404 if the merge request id is used instead of iid' do
      # A merge request in another project takes an id first, so this one's id
      # cannot also be its iid, whatever ran before this example.
      create(:merge_request)

      post api("/projects/#{project.id}/merge_requests/#{merge_request.id}/cancel_merge_when_pipeline_succeeds", user)

      expect(response).to have_gitlab_http_status(:not_found)
    end

    context 'with oauth token that has ai_workflows scope' do
      let(:token) { create(:oauth_access_token, user: user, scopes: [:ai_workflows]) }

      it "does not allow access" do
        post api("/projects/#{project.id}/merge_requests/#{merge_request.iid}/cancel_merge_when_pipeline_succeeds",
          oauth_access_token: token)

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end

    it_behaves_like 'authorizing granular token permissions', :cancel_merge_merge_request do
      let(:boundary_object) { project }
      let(:request) do
        post api("/projects/#{project.id}/merge_requests/#{merge_request.iid}/cancel_merge_when_pipeline_succeeds",
          personal_access_token: pat)
      end
    end
  end

  describe 'POST :id/merge_requests/:merge_request_iid/cancel_auto_merge' do
    let(:merge_request) do
      create(:merge_request, :simple, :merge_when_checks_pass, author: user, assignees: [user],
        source_project: project, target_project: project, source_branch: 'markdown', title: "Test")
    end

    it 'removes the merge_when_pipeline_succeeds status and returns the merge request' do
      post api("/projects/#{project.id}/merge_requests/#{merge_request.iid}/cancel_auto_merge", user)

      expect(response).to have_gitlab_http_status(:created)
      expect(response).to match_response_schema('public_api/v4/merge_request')
      expect(json_response['id']).to eq(merge_request.id)
      expect(json_response['iid']).to eq(merge_request.iid)
      expect(json_response['merge_when_pipeline_succeeds']).to be(false)
      expect(merge_request.reload.auto_merge_enabled).to be(false)
    end

    it 'returns 409 if there is no automatic merge to cancel' do
      merge_request.update!(auto_merge_enabled: false)

      post api("/projects/#{project.id}/merge_requests/#{merge_request.iid}/cancel_auto_merge", user)

      expect(response).to have_gitlab_http_status(:conflict)
      expect(json_response['message']).to eq("Can't cancel the automatic merge")
    end

    it 'returns 403 if the user cannot cancel the automatic merge' do
      post api("/projects/#{project.id}/merge_requests/#{merge_request.iid}/cancel_auto_merge", user2)

      expect(response).to have_gitlab_http_status(:forbidden)
      expect(json_response['message']).to eq('403 Forbidden')
      expect(merge_request.reload.auto_merge_enabled).to be(true)
    end

    context 'when the author cannot merge the merge request' do
      let(:merge_request) do
        create(:merge_request, :simple, :merge_when_checks_pass, author: user2,
          source_project: project, target_project: project, source_branch: 'markdown', title: "Test")
      end

      it 'cancels the automatic merge and returns the merge request' do
        post api("/projects/#{project.id}/merge_requests/#{merge_request.iid}/cancel_auto_merge", user2)

        expect(response).to have_gitlab_http_status(:created)
        expect(json_response['iid']).to eq(merge_request.iid)
        expect(json_response['merge_when_pipeline_succeeds']).to be(false)
        expect(merge_request.reload.auto_merge_enabled).to be(false)
      end
    end

    it 'returns 404 if the merge request is not found' do
      post api("/projects/#{project.id}/merge_requests/#{non_existing_record_iid}/cancel_auto_merge", user)

      expect(response).to have_gitlab_http_status(:not_found)
    end

    it 'returns 404 if the merge request id is used instead of iid' do
      post api("/projects/#{project.id}/merge_requests/#{merge_request_id_not_used_as_iid}/cancel_auto_merge", user)

      expect(response).to have_gitlab_http_status(:not_found)
    end

    context 'with oauth token that has ai_workflows scope' do
      let(:token) { create(:oauth_access_token, user: user, scopes: [:ai_workflows]) }

      it "does not allow access" do
        post api("/projects/#{project.id}/merge_requests/#{merge_request.iid}/cancel_auto_merge",
          oauth_access_token: token)

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end

    it_behaves_like 'authorizing granular token permissions', :cancel_merge_merge_request do
      let(:boundary_object) { project }
      let(:request) do
        post api("/projects/#{project.id}/merge_requests/#{merge_request.iid}/cancel_auto_merge",
          personal_access_token: pat)
      end
    end
  end

  describe 'PUT :id/merge_requests/:merge_request_iid/rebase' do
    include_context 'with a merge request created once'

    context 'with oauth token that has ai_workflows scope' do
      let(:token) { create(:oauth_access_token, user: user, scopes: [:ai_workflows]) }

      it 'enqueues a rebase of the merge request' do
        Sidekiq::Testing.fake! do
          expect do
            put api("/projects/#{project.id}/merge_requests/#{merge_request.iid}/rebase", oauth_access_token: token)
          end.to change { RebaseWorker.jobs.size }.by(1)
        end

        expect(response).to have_gitlab_http_status(:accepted)
        expect(json_response['rebase_in_progress']).to be(true)
      end

      it 'allows access to the project passed as a full path' do
        Sidekiq::Testing.fake! do
          put api("/projects/#{CGI.escape(project.full_path)}/merge_requests/#{merge_request.iid}/rebase",
            oauth_access_token: token)
        end

        expect(response).to have_gitlab_http_status(:accepted)
      end

      context 'when the user cannot push to the branch' do
        let(:guest) { create(:user, guest_of: project) }
        let(:token) { create(:oauth_access_token, user: guest, scopes: [:ai_workflows]) }

        it 'returns 403' do
          put api("/projects/#{project.id}/merge_requests/#{merge_request.iid}/rebase", oauth_access_token: token)

          expect(response).to have_gitlab_http_status(:forbidden)
          expect(json_response['message']).to eq('403 Forbidden - Cannot push to source branch')
        end
      end

      context 'with a composite identity token' do
        let(:service_account) { create(:user, :service_account, composite_identity_enforced: true) }
        let(:human_user) { create(:user) }
        let(:token) do
          create(:oauth_access_token, user: service_account, scopes: [:ai_workflows, :"user:#{human_user.id}"])
        end

        let(:rebase_request) do
          put api("/projects/#{project.id}/merge_requests/#{merge_request.iid}/rebase", oauth_access_token: token)
        end

        context 'when both identities can push to the branch' do
          before do
            project.add_developer(service_account)
            project.add_developer(human_user)
          end

          it 'enqueues a rebase of the merge request' do
            Sidekiq::Testing.fake! do
              expect { rebase_request }.to change { RebaseWorker.jobs.size }.by(1)
            end

            expect(response).to have_gitlab_http_status(:accepted)
          end
        end

        context 'when the service account cannot push to the branch' do
          before do
            project.add_guest(service_account)
            project.add_developer(human_user)
          end

          it 'returns 403' do
            rebase_request

            expect(response).to have_gitlab_http_status(:forbidden)
            expect(json_response['message']).to eq('403 Forbidden - Cannot push to source branch')
          end
        end

        context 'when the human user cannot push to the branch' do
          before do
            project.add_developer(service_account)
            project.add_guest(human_user)
          end

          it 'returns 403' do
            rebase_request

            expect(response).to have_gitlab_http_status(:forbidden)
            expect(json_response['message']).to eq('403 Forbidden - Cannot push to source branch')
          end
        end
      end
    end

    context 'when rebase can be performed' do
      context 'when skip_ci parameter is set' do
        it 'enqueues a rebase of the merge request with skip_ci flag set' do
          with_status = RebaseWorker.with_status

          expect(RebaseWorker).to receive(:with_status).and_return(with_status)
          expect(with_status).to receive(:perform_async).with(merge_request.id, user.id, true).and_call_original

          Sidekiq::Testing.fake! do
            expect do
              put api("/projects/#{project.id}/merge_requests/#{merge_request.iid}/rebase", user),
                params: { skip_ci: true }
            end.to change { RebaseWorker.jobs.size }.by(1)
          end

          expect(response).to have_gitlab_http_status(:accepted)
          expect(merge_request.reload).to be_rebase_in_progress
          expect(json_response['rebase_in_progress']).to be(true)
        end
      end

      it_behaves_like 'authorizing granular token permissions', :rebase_merge_request do
        let(:boundary_object) { project }
        let(:request) do
          put api("/projects/#{project.id}/merge_requests/#{merge_request.iid}/rebase", personal_access_token: pat)
        end
      end

      it_behaves_like 'rate limited endpoint', rate_limit_key: :merge_requests_rebase, use_second_scope: false do
        let(:current_user) { user }

        def request
          put api("/projects/#{project.id}/merge_requests/#{merge_request.iid}/rebase", user)
        end
      end

      context 'when merge_requests_rebase_rate_limit is disabled' do
        before do
          stub_feature_flags(merge_requests_rebase_rate_limit: false)
        end

        it_behaves_like 'unthrottled endpoint', rate_limit_key: :merge_requests_rebase do
          def request
            put api("/projects/#{project.id}/merge_requests/#{merge_request.iid}/rebase", user)
          end
        end
      end
    end

    it 'does not check the rate limit if the user cannot push to the branch' do
      guest = create(:user, guest_of: project)

      expect(Gitlab::ApplicationRateLimiter).not_to receive(:throttled_request?)
        .with(anything, anything, :merge_requests_rebase, any_args)

      put api("/projects/#{project.id}/merge_requests/#{merge_request.iid}/rebase", guest)

      expect(response).to have_gitlab_http_status(:forbidden)
    end

    it 'returns 409 if a rebase is already in progress' do
      Sidekiq::Testing.fake! do
        merge_request.rebase_async(user.id)

        put api("/projects/#{project.id}/merge_requests/#{merge_request.iid}/rebase", user)
      end

      expect(response).to have_gitlab_http_status(:conflict)
    end

    it "returns 409 if rebase can't lock the row" do
      allow_next_found_instance_of(MergeRequest) do |merge_request|
        allow(merge_request).to receive(:with_lock).and_raise(ActiveRecord::LockWaitTimeout)
      end
      expect(RebaseWorker).not_to receive(:perform_async)

      put api("/projects/#{project.id}/merge_requests/#{merge_request.iid}/rebase", user)

      expect(response).to have_gitlab_http_status(:conflict)
      expect(json_response['message']).to eq(
        'Failed to enqueue the rebase operation, possibly due to a long-lived transaction. Try again later.'
      )
    end
  end
end
