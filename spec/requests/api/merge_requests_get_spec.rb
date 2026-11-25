# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::MergeRequests, :aggregate_failures, feature_category: :source_code_management do
  include_context 'with merge requests API setup'

  shared_examples 'merge request diff read rate limited' do |route:, sibling_route:|
    include_context 'workhorse headers'

    let_it_be(:other_merge_request) do
      create(:merge_request, :simple, author: user, source_project: project, target_project: project,
        source_branch: 'improve/awesome')
    end

    def read_diffs(route, as: user, mr: merge_request, ip: '10.0.0.1')
      get api("/projects/#{project.id}/merge_requests/#{mr.iid}/#{route}", as),
        headers: workhorse_headers, env: { REMOTE_ADDR: ip }
    end

    before do
      stub_application_setting(merge_requests_read_diffs_limit: 1)
    end

    it_behaves_like 'rate limited endpoint', rate_limit_key: :merge_requests_read_diffs do
      let(:current_user) { user }
      let(:diff_route) { route }

      def request
        read_diffs(diff_route)
      end

      def request_with_second_scope
        read_diffs(diff_route, as: user2)
      end
    end

    it 'throttles a user who already read another merge request through a sibling route' do
      read_diffs(sibling_route, mr: other_merge_request)
      expect(response).to have_gitlab_http_status(:ok)

      read_diffs(route)

      expect(response).to have_gitlab_http_status(:too_many_requests)
      expect(response.headers['RateLimit-Name']).to eq('merge_requests_read_diffs')
      expect(response.headers[Gitlab::Workhorse::SEND_DATA_HEADER]).to be_nil
    end

    it 'throttles an anonymous caller by IP address' do
      read_diffs(route, as: nil, ip: '10.0.0.7')
      expect(response).to have_gitlab_http_status(:ok)

      read_diffs(route, as: nil, ip: '10.0.0.7')

      expect(response).to have_gitlab_http_status(:too_many_requests)

      read_diffs(route, as: nil, ip: '10.0.0.8')

      expect(response).to have_gitlab_http_status(:ok)
    end
  end

  describe "GET /projects/:id/merge_requests/:merge_request_iid" do
    let(:merge_request) do
      create(:merge_request, :simple, author: user, assignees: [user], milestone: milestone, source_project: project,
        source_branch: 'markdown', title: "Test")
    end

    it_behaves_like 'enforcing job token policies', :read_merge_requests,
      allow_public_access_for_enabled_project_features: [:repository, :merge_requests] do
      let(:request) do
        get api("/projects/#{project.id}/merge_requests/#{merge_request.iid}"), params: { job_token: target_job.token }
      end
    end

    context 'with oauth token that has ai_workflows scope' do
      let(:user) { create(:user) }
      let(:token) { create(:oauth_access_token, user: user, scopes: [:ai_workflows]) }

      it "allows access" do
        get api(
          "/projects/#{project.id}/merge_requests/#{merge_request.iid}",
          oauth_access_token: token
        )

        expect(response).to have_gitlab_http_status(:ok)
      end
    end

    it 'matches json schema' do
      merge_request = create(:merge_request, :with_test_reports, milestone: milestone1, author: user,
        assignees: [user], source_project: project, target_project: project, title: "Test", created_at: base_time)
      get api("/projects/#{project.id}/merge_requests/#{merge_request.iid}", user)

      expect(response).to have_gitlab_http_status(:ok)
      expect(response).to match_response_schema('public_api/v4/merge_request')
    end

    it 'exposes known attributes' do
      create(:award_emoji, :downvote, awardable: merge_request)
      create(:award_emoji, :upvote, awardable: merge_request)

      get api("/projects/#{project.id}/merge_requests/#{merge_request.iid}", user)

      expect(response).to have_gitlab_http_status(:ok)
      expect(json_response['id']).to eq(merge_request.id)
      expect(json_response['iid']).to eq(merge_request.iid)
      expect(json_response['project_id']).to eq(merge_request.project.id)
      expect(json_response['title']).to eq(merge_request.title)
      expect(json_response['description']).to eq(merge_request.description)
      expect(json_response['state']).to eq(merge_request.state)
      expect(json_response['created_at']).to be_present
      expect(json_response['updated_at']).to be_present
      expect(json_response['labels']).to eq(merge_request.label_names)
      expect(json_response['milestone']).to be_a Hash
      expect(json_response['assignee']).to be_a Hash
      expect(json_response['author']).to be_a Hash
      expect(json_response['target_branch']).to eq(merge_request.target_branch)
      expect(json_response['source_branch']).to eq(merge_request.source_branch)
      expect(json_response['upvotes']).to eq(1)
      expect(json_response['downvotes']).to eq(1)
      expect(json_response['source_project_id']).to eq(merge_request.source_project.id)
      expect(json_response['target_project_id']).to eq(merge_request.target_project.id)
      expect(json_response['draft']).to be false
      expect(json_response['work_in_progress']).to be false
      expect(json_response['merge_when_pipeline_succeeds']).to be false
      expect(json_response['merge_status']).to eq('can_be_merged')
      expect(json_response['changes_count']).to eq(merge_request.merge_request_diff.real_size)
      expect(json_response['merge_error']).to eq(merge_request.merge_error)
      expect(json_response['user']['can_merge']).to be_truthy
      expect(json_response).not_to include('rebase_in_progress')
      expect(json_response['first_contribution']).to be true
      expect(json_response['has_conflicts']).to be false
      expect(json_response['blocking_discussions_resolved']).to be_truthy
      expect(json_response['references']['short']).to eq("!#{merge_request.iid}")
      expect(json_response['references']['relative']).to eq("!#{merge_request.iid}")
      expect(json_response['references']['full'])
        .to eq("#{merge_request.target_project.full_path}!#{merge_request.iid}")
    end

    it 'exposes description and title html when render_html is true' do
      get api("/projects/#{project.id}/merge_requests/#{merge_request.iid}", user), params: { render_html: true }

      expect(response).to have_gitlab_http_status(:ok)

      expect(json_response).to include('title_html', 'description_html')
    end

    it 'exposes rebase_in_progress when include_rebase_in_progress is true' do
      get api("/projects/#{project.id}/merge_requests/#{merge_request.iid}", user),
        params: { include_rebase_in_progress: true }

      expect(response).to have_gitlab_http_status(:ok)

      expect(json_response).to include('rebase_in_progress')
    end

    context 'when merge request author has only guest access' do
      it_behaves_like 'rejects user from accessing merge request info' do
        let(:url) { "/projects/#{project.id}/merge_requests/#{merge_request.iid}" }
      end
    end

    context 'with merge_request_metrics' do
      let_it_be_with_reload(:milestone) { create(:milestone, title: '1.0.0', project: project) }
      let_it_be_with_reload(:merge_request) do
        create(:merge_request, :simple, author: user, assignees: [user], milestone: milestone, source_project: project,
          source_branch: 'markdown', title: "Test")
      end

      let(:pipeline) { create(:ci_pipeline) }

      before do
        merge_request.metrics.update!(
          merged_by: user,
          latest_closed_by: user,
          latest_closed_at: 1.hour.ago,
          merged_at: 2.hours.ago,
          pipeline: pipeline,
          latest_build_started_at: 3.hours.ago,
          latest_build_finished_at: 1.hour.ago,
          first_deployed_to_production_at: 3.minutes.ago
        )
      end

      it 'returns correct values' do
        get api("/projects/#{project.id}/merge_requests/#{merge_request.iid}", user)

        expect(json_response['merged_by']['id']).to eq(merge_request.metrics.merged_by_id)
        expect(json_response['merge_user']['id']).to eq(merge_request.metrics.merged_by_id)
        expect(Time.parse(json_response['merged_at'])).to be_like_time(merge_request.metrics.merged_at)
        expect(json_response['closed_by']['id']).to eq(merge_request.metrics.latest_closed_by_id)
        expect(Time.parse(json_response['closed_at'])).to be_like_time(merge_request.metrics.latest_closed_at)
        expect(json_response['pipeline']['id']).to eq(merge_request.metrics.pipeline_id)
        metrics = merge_request.metrics
        expect(Time.parse(json_response['latest_build_started_at'])).to be_like_time(metrics.latest_build_started_at)
        expect(Time.parse(json_response['latest_build_finished_at'])).to be_like_time(metrics.latest_build_finished_at)
        expect(Time.parse(json_response['first_deployed_to_production_at']))
          .to be_like_time(metrics.first_deployed_to_production_at)
      end
    end

    context 'with merge_user' do
      context 'when MR is set to auto merge' do
        let_it_be_with_reload(:merge_request) do
          create(:merge_request, :merge_when_checks_pass, source_project: project, target_project: project)
        end

        it 'returns user who set to auto merge' do
          get api("/projects/#{project.id}/merge_requests/#{merge_request.iid}", user)

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response['merge_user']['id']).to eq(user.id)
        end

        context 'when MR is already merged' do
          before do
            merge_request.metrics.update!(merged_by: user2)
          end

          it 'returns user who actually merged' do
            get api("/projects/#{project.id}/merge_requests/#{merge_request.iid}", user)

            expect(response).to have_gitlab_http_status(:ok)
            expect(json_response['merge_user']['id']).to eq(user2.id)
          end
        end
      end
    end

    context 'with head_pipeline' do
      let_it_be_with_reload(:project) { create(:project, :public, :repository, reporters: user) }
      let_it_be_with_reload(:merge_request) do
        create(:merge_request, :simple, author: user, source_project: project, source_branch: 'markdown', title: "Test")
      end

      before do
        merge_request.update!(head_pipeline: create(:ci_pipeline))
        merge_request.project.project_feature.update!(builds_access_level: 10)
      end

      it 'exposes pipeline information' do
        get api("/projects/#{project.id}/merge_requests/#{merge_request.iid}", user)

        expect(json_response).to include('head_pipeline')
      end

      it 'does not expose pipeline information to a user who cannot read pipelines' do
        get api("/projects/#{project.id}/merge_requests/#{merge_request.iid}", create(:user))

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response).not_to include('head_pipeline')
      end
    end

    it 'returns the commits behind the target branch when include_diverged_commits_count is present' do
      allow_next_found_instance_of(MergeRequest) do |merge_request|
        allow(merge_request).to receive(:diverged_commits_count).and_return(1)
      end

      get api("/projects/#{project.id}/merge_requests/#{merge_request.iid}", user),
        params: { include_diverged_commits_count: true }

      expect(response).to have_gitlab_http_status(:ok)
      expect(json_response['diverged_commits_count']).to eq(1)
    end

    it "returns a 404 error if merge_request_iid not found" do
      get api("/projects/#{project.id}/merge_requests/0", user)
      expect(response).to have_gitlab_http_status(:not_found)
    end

    it "returns a 404 error if merge_request `id` is used instead of iid" do
      get api("/projects/#{project.id}/merge_requests/#{merge_request_id_not_used_as_iid}", user)

      expect(response).to have_gitlab_http_status(:not_found)
    end

    context 'with a draft merge request' do
      let!(:merge_request_draft) do
        create(:merge_request,
          author: user,
          assignees: [user],
          source_project: project,
          target_project: project,
          title: "Draft: Test",
          created_at: base_time + 1.second
        )
      end

      it "returns merge request" do
        get api("/projects/#{project.id}/merge_requests/#{merge_request_draft.iid}", user)

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response['draft']).to be(true)
        expect(json_response['work_in_progress']).to be(true)
      end
    end

    context 'when a merge request has more than the changes limit' do
      it "returns a string indicating that more changes were made" do
        allow(Commit).to receive(:diff_max_files).and_return(5)

        merge_request_overflow = create(
          :merge_request, :simple,
          author: user,
          assignees: [user],
          source_project: project,
          source_branch: 'expand-collapse-files',
          target_project: project,
          target_branch: 'master'
        )

        get api("/projects/#{project.id}/merge_requests/#{merge_request_overflow.iid}", user)

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response['changes_count']).to eq('5+')
      end
    end

    context 'for forked projects' do
      let(:user2) { create(:user) }
      let(:project) { create(:project, :public, :repository) }
      let(:forked_project) { fork_project(project, user2, repository: true) }
      let(:merge_request) do
        create(
          :merge_request,
          source_project: forked_project,
          target_project: project,
          source_branch: 'fixes',
          allow_collaboration: true
        )
      end

      it 'includes the `allow_collaboration` field', :sidekiq_might_not_need_inline do
        get api("/projects/#{project.id}/merge_requests/#{merge_request.iid}", user)

        expect(json_response['allow_collaboration']).to be_truthy
        expect(json_response['allow_maintainer_to_push']).to be_truthy
      end
    end

    it 'indicates if a user cannot merge the MR' do
      user2 = create(:user)
      project.add_reporter(user2)

      get api("/projects/#{project.id}/merge_requests/#{merge_request.iid}", user2)

      expect(json_response['user']['can_merge']).to be false
    end

    it 'returns `checking` as its merge_status instead of `cannot_be_merged_rechecking`' do
      merge_request.update!(merge_status: 'cannot_be_merged_rechecking')

      get api("/projects/#{project.id}/merge_requests/#{merge_request.iid}", user)

      expect(json_response['merge_status']).to eq 'checking'
    end

    context 'when merge request is unchecked' do
      before do
        merge_request.mark_as_unchecked!
      end

      it 'checks mergeability asynchronously' do
        expect_next_instance_of(MergeRequests::MergeabilityCheckService) do |service|
          expect(service).not_to receive(:execute)
          expect(service).to receive(:async_execute)
        end

        get api("/projects/#{project.id}/merge_requests/#{merge_request.iid}", user)
      end
    end

    it_behaves_like 'authorizing granular token permissions', :read_merge_request do
      let(:boundary_object) { project }
      let(:request) do
        get api("/projects/#{project.id}/merge_requests/#{merge_request.iid}", personal_access_token: pat)
      end
    end
  end

  describe 'GET /projects/:id/merge_requests/:merge_request_iid/participants' do
    it_behaves_like 'issuable participants endpoint' do
      let(:entity) do
        create(:merge_request, :simple, milestone: milestone1, author: user, assignees: [user], source_project: project,
          target_project: project, source_branch: 'markdown', title: "Test", created_at: base_time)
      end
    end

    context 'when merge request author has only guest access' do
      it_behaves_like 'rejects user from accessing merge request info' do
        let(:url) { "/projects/#{project.id}/merge_requests/#{merge_request.iid}/participants" }
      end
    end

    it_behaves_like 'authorizing granular token permissions', :read_merge_request_participant do
      let(:boundary_object) { project }
      let(:request) do
        get api("/projects/#{project.id}/merge_requests/#{merge_request.iid}/participants", personal_access_token: pat)
      end
    end
  end

  describe 'GET /projects/:id/merge_requests/:merge_request_iid/reviewers' do
    include_context 'with a merge request created once'

    it 'returns reviewers' do
      reviewer = create(:user)
      merge_request.merge_request_reviewers.create!(reviewer: reviewer)

      get api("/projects/#{project.id}/merge_requests/#{merge_request.iid}/reviewers", user)

      expect(response).to have_gitlab_http_status(:ok)
      expect(response).to include_pagination_headers
      expect(json_response).to be_an Array
      expect(json_response.size).to eq(merge_request.merge_request_reviewers.size)

      expect(json_response.last['user']['id']).to eq(reviewer.id)
      expect(json_response.last['user']['name']).to eq(reviewer.name)
      expect(json_response.last['user']['username']).to eq(reviewer.username)
      expect(json_response.last['state']).to eq('unreviewed')
      expect(json_response.last['created_at']).to be_present
    end

    it 'returns a 404 when iid does not exist' do
      get api("/projects/#{project.id}/merge_requests/#{non_existing_record_iid}/reviewers", user)

      expect(response).to have_gitlab_http_status(:not_found)
    end

    it 'returns a 404 when id is used instead of iid' do
      get api("/projects/#{project.id}/merge_requests/#{merge_request_id_not_used_as_iid}/reviewers", user)

      expect(response).to have_gitlab_http_status(:not_found)
    end

    context 'when merge request author has only guest access' do
      it_behaves_like 'rejects user from accessing merge request info' do
        let(:url) { "/projects/#{project.id}/merge_requests/#{merge_request.iid}/reviewers" }
      end
    end

    it_behaves_like 'authorizing granular token permissions', :read_merge_request_reviewer do
      let(:boundary_object) { project }
      let(:request) do
        get api("/projects/#{project.id}/merge_requests/#{merge_request.iid}/reviewers", personal_access_token: pat)
      end
    end
  end

  describe 'GET /projects/:id/merge_requests/:merge_request_iid/commits' do
    include_context 'with merge requests'

    describe 'mcp route setting' do
      subject { get api("/projects/#{project.id}/merge_requests/#{merge_request.iid}/commits", user) }

      it_behaves_like 'an endpoint with mcp route setting', :get_merge_request_commits,
        expected_params: [:id, :merge_request_iid, :per_page, :page]
    end

    it 'returns a 200 when merge request is valid' do
      get api("/projects/#{project.id}/merge_requests/#{merge_request.iid}/commits", user)
      commit = merge_request.merge_request_diff.last_commit

      expect_successful_response_with_paginated_array
      expect(json_response.size).to eq(merge_request.commits.size)
      expect(json_response.first['id']).to eq(commit.id)
      expect(json_response.first['title']).to eq(commit.title)
      expect(json_response.first['parent_ids']).to be_present
    end

    context 'when optimized_commit_storage feature flag is disabled' do
      before do
        stub_feature_flags(optimized_commit_storage: false)
      end

      it 'returns a 200 with parent_ids' do
        get api("/projects/#{project.id}/merge_requests/#{merge_request.iid}/commits", user)
        commit = merge_request.merge_request_diff.last_commit

        expect_successful_response_with_paginated_array
        expect(json_response.size).to eq(merge_request.commits.size)
        expect(json_response.first['id']).to eq(commit.id)
        expect(json_response.first['title']).to eq(commit.title)
        expect(json_response.first['parent_ids']).to be_present
      end
    end

    it 'returns a 404 when merge_request_iid not found' do
      get api("/projects/#{project.id}/merge_requests/0/commits", user)
      expect(response).to have_gitlab_http_status(:not_found)
    end

    it 'returns a 404 when merge_request id is used instead of iid' do
      get api("/projects/#{project.id}/merge_requests/#{merge_request_id_not_used_as_iid}/commits", user)

      expect(response).to have_gitlab_http_status(:not_found)
    end

    context 'when merge request author has only guest access' do
      it_behaves_like 'rejects user from accessing merge request info' do
        let(:url) { "/projects/#{project.id}/merge_requests/#{merge_request.iid}/commits" }
      end
    end

    it_behaves_like 'authorizing granular token permissions', :read_merge_request_commit do
      let(:boundary_object) { project }
      let(:request) do
        get api("/projects/#{project.id}/merge_requests/#{merge_request.iid}/commits", personal_access_token: pat)
      end
    end
  end

  describe 'GET /projects/:id/merge_requests/:merge_request_iid/:context_commits' do
    let_it_be(:merge_request, freeze: false) do
      create(:merge_request, :simple, author: user, source_project: project, target_project: project,
        source_branch: 'markdown', title: "Test", created_at: base_time)
    end

    let_it_be(:merge_request_context_commit) do
      create(:merge_request_context_commit, merge_request: merge_request, message: 'test')
    end

    it 'returns a 200 when merge request is valid' do
      context_commit = merge_request.context_commits.first

      get api("/projects/#{project.id}/merge_requests/#{merge_request.iid}/context_commits", user)

      expect_successful_response_with_paginated_array
      expect(json_response.size).to eq(merge_request.context_commits.size)
      expect(json_response.first['id']).to eq(context_commit.id)
      expect(json_response.first['title']).to eq(context_commit.title)
    end

    it 'returns the attributes of the entity the endpoint documents' do
      route = described_class.routes.find do |r|
        r.request_method == 'GET' && r.path.include?('/merge_requests/:merge_request_iid/context_commits')
      end
      documented_keys = route.options[:entity].root_exposures.map { |exposure| exposure.key.to_s }

      get api("/projects/#{project.id}/merge_requests/#{merge_request.iid}/context_commits", user)

      expect(response).to have_gitlab_http_status(:ok)
      expect(json_response.first.keys).to match_array(documented_keys)
    end

    it 'returns a 404 when merge_request_iid not found' do
      get api("/projects/#{project.id}/merge_requests/0/context_commits", user)
      expect(response).to have_gitlab_http_status(:not_found)
    end

    it_behaves_like 'authorizing granular token permissions', :read_merge_request_context_commit do
      let(:boundary_object) { project }
      let(:request) do
        get api("/projects/#{project.id}/merge_requests/#{merge_request.iid}/context_commits",
          personal_access_token: pat)
      end
    end
  end

  describe 'GET /projects/:id/merge_requests/:merge_request_iid/changes' do
    let_it_be_with_refind(:merge_request) do
      create(
        :merge_request,
        :simple,
        author: user,
        assignees: [user],
        source_project: project,
        target_project: project,
        source_branch: 'markdown',
        title: "Test",
        created_at: base_time
      )
    end

    context 'with the diff read rate limit', :clean_gitlab_redis_rate_limiting do
      it_behaves_like 'merge request diff read rate limited', route: 'changes', sibling_route: 'diffs'
    end

    shared_examples 'find an existing merge request' do
      it 'returns the change information of the merge_request' do
        get api("/projects/#{project.id}/merge_requests/#{merge_request.iid}/changes", user)

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response['changes'].size).to eq(merge_request.diffs.size)
        expect(json_response['overflow']).to be_falsy
      end
    end

    it_behaves_like 'authorizing granular token permissions', :read_merge_request_diff do
      let(:boundary_object) { project }
      let(:request) do
        get api("/projects/#{project.id}/merge_requests/#{merge_request.iid}/changes", personal_access_token: pat)
      end
    end

    it 'returns a 404 when merge_request_iid not found' do
      get api("/projects/#{project.id}/merge_requests/0/changes", user)
      expect(response).to have_gitlab_http_status(:not_found)
    end

    it 'returns a 404 when merge_request id is used instead of iid' do
      get api("/projects/#{project.id}/merge_requests/#{merge_request_id_not_used_as_iid}/changes", user)

      expect(response).to have_gitlab_http_status(:not_found)
    end

    context 'when merge request author has only guest access' do
      it_behaves_like 'rejects user from accessing merge request info' do
        let(:url) { "/projects/#{project.id}/merge_requests/#{merge_request.iid}/changes" }
      end
    end

    it_behaves_like 'find an existing merge request'

    context 'when unidiff format is requested' do
      it 'returns the diff in Unified format' do
        get api("/projects/#{project.id}/merge_requests/#{merge_request.iid}/changes", user), params: { unidiff: true }

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response.dig('changes', 0, 'diff')).to eq(merge_request.diffs.diffs.first.unidiff)
      end
    end

    context 'when using DB-backed diffs' do
      context 'when the diff_collection has overflowed its size limits' do
        it 'returns the overflow status as true' do
          expect_next_instance_of(Gitlab::Git::DiffCollection) do |diff_collection|
            expect(diff_collection).to receive(:overflow?).and_return(true)
          end

          get api("/projects/#{project.id}/merge_requests/#{merge_request.iid}/changes", user)

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response['overflow']).to be_truthy
        end
      end
    end
  end

  describe 'GET /projects/:id/merge_requests/:merge_request_iid/diffs' do
    let_it_be(:merge_request, freeze: false) do
      create(
        :merge_request,
        :simple,
        author: user,
        assignees: [user],
        source_project: project,
        target_project: project,
        source_branch: 'markdown',
        title: "Test",
        created_at: base_time
      )
    end

    context 'with the diff read rate limit', :clean_gitlab_redis_rate_limiting do
      it_behaves_like 'merge request diff read rate limited', route: 'diffs', sibling_route: 'raw_diffs'
    end

    describe 'mcp route setting' do
      subject { get api("/projects/#{project.id}/merge_requests/#{merge_request.iid}/diffs", user) }

      it_behaves_like 'an endpoint with mcp route setting', :get_merge_request_diffs,
        expected_params: [:id, :merge_request_iid, :per_page, :page]
    end

    it_behaves_like 'authorizing granular token permissions', :read_merge_request_diff do
      let(:boundary_object) { project }
      let(:request) do
        get api("/projects/#{project.id}/merge_requests/#{merge_request.iid}/diffs", personal_access_token: pat)
      end
    end

    it 'returns a 404 when merge_request_iid not found' do
      get api("/projects/#{project.id}/merge_requests/0/diffs", user)
      expect(response).to have_gitlab_http_status(:not_found)
    end

    it 'returns a 404 when merge_request id is used instead of iid' do
      get api("/projects/#{project.id}/merge_requests/#{merge_request_id_not_used_as_iid}/diffs", user)

      expect(response).to have_gitlab_http_status(:not_found)
    end

    context 'when merge request author has only guest access' do
      it_behaves_like 'rejects user from accessing merge request info' do
        let(:url) { "/projects/#{project.id}/merge_requests/#{merge_request.iid}/diffs" }
      end
    end

    it 'returns the diffs of the merge_request' do
      get api("/projects/#{project.id}/merge_requests/#{merge_request.iid}/diffs", user)

      expect_successful_response_with_paginated_array
      expect(json_response.size).to eq(merge_request.diffs.size)
    end

    context 'when unidiff format is requested' do
      it 'returns the diff in Unified format' do
        get api("/projects/#{project.id}/merge_requests/#{merge_request.iid}/diffs", user), params: { unidiff: true }

        expect_successful_response_with_paginated_array
        expect(json_response.dig(0, 'diff')).to eq(merge_request.diffs.diffs.first.unidiff)
      end
    end

    context 'when pagination params are present' do
      it 'returns limited diffs' do
        get(
          api("/projects/#{project.id}/merge_requests/#{merge_request.iid}/diffs", user),
          params: { page: 1, per_page: 1 }
        )

        expect_successful_response_with_paginated_array
        expect(json_response.size).to eq(1)
      end

      context 'when per_page is greater than the max_per_page' do
        before do
          allow(Kaminari.config).to receive(:max_per_page).and_return(1)
        end

        it 'returns the correct amount of diffs' do
          get(
            api("/projects/#{project.id}/merge_requests/#{merge_request.iid}/diffs", user),
            params: { per_page: 2 }
          )

          expect_successful_response_with_paginated_array
          expect(json_response.size).to eq(1)
        end
      end

      context 'when diff files exceed safe limits' do
        before do
          allow(Commit).to receive_messages(diff_safe_max_files: 1, diff_safe_max_lines: 1)
        end

        it 'does not collapse diff content on page 1', :aggregate_failures do
          get(
            api("/projects/#{project.id}/merge_requests/#{merge_request.iid}/diffs", user),
            params: { page: 1, per_page: 30 }
          )

          expect_successful_response_with_paginated_array

          non_trivial_diffs = json_response.reject { |diff| diff['deleted_file'] || diff['renamed_file'] }
          expect(non_trivial_diffs).not_to be_empty

          json_response.each do |diff|
            expect(diff['collapsed']).to be false

            next if diff['deleted_file'] || diff['renamed_file']

            expect(diff['diff']).not_to be_empty, "Expected non-empty diff for #{diff['new_path']}"
          end
        end

        it 'does not collapse diff content on subsequent pages', :aggregate_failures do
          get(
            api("/projects/#{project.id}/merge_requests/#{merge_request.iid}/diffs", user),
            params: { page: 2, per_page: 1 }
          )

          expect_successful_response_with_paginated_array

          non_trivial_diffs = json_response.reject { |diff| diff['deleted_file'] || diff['renamed_file'] }
          expect(non_trivial_diffs).not_to be_empty

          json_response.each do |diff|
            expect(diff['collapsed']).to be false

            next if diff['deleted_file'] || diff['renamed_file']

            expect(diff['diff']).not_to be_empty, "Expected non-empty diff for #{diff['new_path']}"
          end
        end
      end
    end
  end

  describe 'GET /projects/:id/merge_requests/:merge_request_iid/raw_diffs' do
    include_context 'workhorse headers'

    let_it_be(:merge_request, freeze: false) do
      create(
        :merge_request,
        :simple,
        author: user,
        assignees: [user],
        source_project: project,
        target_project: project,
        source_branch: 'markdown',
        title: "Test",
        created_at: base_time
      )
    end

    context 'with the diff read rate limit', :clean_gitlab_redis_rate_limiting do
      it_behaves_like 'merge request diff read rate limited', route: 'raw_diffs', sibling_route: 'changes'
    end

    it 'returns a 404 when merge_request_iid not found' do
      get api("/projects/#{project.id}/merge_requests/0/raw_diffs", user), headers: workhorse_headers
      expect(response).to have_gitlab_http_status(:not_found)
    end

    it 'returns a 404 when merge_request id is used instead of iid' do
      get api("/projects/#{project.id}/merge_requests/#{merge_request_id_not_used_as_iid}/raw_diffs", user),
        headers: workhorse_headers

      expect(response).to have_gitlab_http_status(:not_found)
    end

    context 'when merge request author has only guest access' do
      it_behaves_like 'rejects user from accessing merge request info' do
        let(:url) { "/projects/#{project.id}/merge_requests/#{merge_request.iid}/raw_diffs" }
      end
    end

    it 'returns the a workhorse git-diff url' do
      get api("/projects/#{project.id}/merge_requests/#{merge_request.iid}/raw_diffs", user), headers: workhorse_headers

      expect(response).to have_gitlab_http_status(:ok)
      expect(response.headers[Gitlab::Workhorse::SEND_DATA_HEADER]).to start_with("git-diff:")
    end

    it_behaves_like 'authorizing granular token permissions', :read_merge_request_raw_diff do
      let(:boundary_object) { project }
      let(:request) do
        get api("/projects/#{project.id}/merge_requests/#{merge_request.iid}/raw_diffs", personal_access_token: pat),
          headers: workhorse_headers
      end
    end
  end

  describe 'merge request diff read rate limit', :clean_gitlab_redis_rate_limiting do
    let_it_be(:merge_request, freeze: false) do
      create(:merge_request, :simple, author: user, source_project: project, target_project: project,
        source_branch: 'markdown')
    end

    def read_diffs(as: user)
      get api("/projects/#{project.id}/merge_requests/#{merge_request.iid}/changes", as)
    end

    before do
      stub_application_setting(merge_requests_read_diffs_limit: 1)
    end

    it 'does not throttle another user' do
      read_diffs
      read_diffs(as: user2)

      expect(response).to have_gitlab_http_status(:ok)
    end

    context 'when the limit is set to 0' do
      before do
        stub_application_setting(merge_requests_read_diffs_limit: 0)
      end

      it 'does not throttle' do
        3.times { read_diffs }

        expect(response).to have_gitlab_http_status(:ok)
      end
    end

    context 'when merge_requests_read_diffs_rate_limit_enforce is enabled only for the instance' do
      before do
        stub_feature_flags(merge_requests_read_diffs_rate_limit_enforce: Feature.gitlab_instance)
      end

      it 'throttles an anonymous caller' do
        read_diffs(as: nil)
        read_diffs(as: nil)

        expect(response).to have_gitlab_http_status(:too_many_requests)
      end
    end

    context 'when merge_requests_read_diffs_rate_limit_enforce is disabled' do
      before do
        stub_feature_flags(merge_requests_read_diffs_rate_limit_enforce: false)
      end

      it 'counts the reads in log mode without throttling' do
        states = []
        allow(Gitlab::Instrumentation::RateLimitState).to receive(:track).and_wrap_original do |original, *args|
          original.call(*args)
          states.concat(Gitlab::Instrumentation::RateLimitState.payload.fetch(:rate_limit_state, []))
        end

        read_diffs
        read_diffs

        expect(response).to have_gitlab_http_status(:ok)
        expect(states).to include(
          'applimiter_merge_requests_read_diffs:limit_merge_request_diff_reads_by_user_or_ip_log:log'
        )
      end
    end
  end

  describe 'GET /projects/:id/merge_requests/:merge_request_iid/pipelines' do
    let_it_be(:merge_request, freeze: false) do
      create(:merge_request, :simple, author: user, assignees: [user], source_project: project, target_project: project,
        source_branch: 'markdown', title: "Test", created_at: base_time)
    end

    context 'when authorized' do
      let_it_be(:pipeline) do
        create(:ci_pipeline, project: project, user: user, ref: merge_request.source_branch,
          sha: merge_request.diff_head_sha)
      end

      let_it_be(:pipeline2) { create(:ci_pipeline, project: project) }

      describe 'mcp route setting' do
        subject { get api("/projects/#{project.id}/merge_requests/#{merge_request.iid}/pipelines", user) }

        it_behaves_like 'an endpoint with mcp route setting', :get_merge_request_pipelines,
          expected_params: [:id, :merge_request_iid, :per_page, :page]
      end

      it_behaves_like 'authorizing granular token permissions', :read_merge_request_pipeline do
        let(:boundary_object) { project }
        let(:request) do
          get api("/projects/#{project.id}/merge_requests/#{merge_request.iid}/pipelines", personal_access_token: pat)
        end
      end

      it 'returns a paginated array of corresponding pipelines' do
        get api("/projects/#{project.id}/merge_requests/#{merge_request.iid}/pipelines")

        expect_successful_response_with_paginated_array
        expect(json_response.count).to eq(1)
        expect(json_response.first['id']).to eq(pipeline.id)
      end

      context 'with oauth token that has ai_workflows scope' do
        let(:token) { create(:oauth_access_token, user: user, scopes: [:ai_workflows]) }

        it "allows access" do
          get api(
            "/projects/#{project.id}/merge_requests/#{merge_request.iid}/pipelines",
            oauth_access_token: token
          )

          expect_successful_response_with_paginated_array
        end
      end

      it 'exposes basic attributes' do
        get api("/projects/#{project.id}/merge_requests/#{merge_request.iid}/pipelines")

        expect(response).to have_gitlab_http_status(:ok)
        expect(response).to match_response_schema('public_api/v4/pipelines')
      end

      it 'returns 404 if MR does not exist' do
        get api("/projects/#{project.id}/merge_requests/#{non_existing_record_iid}/pipelines")

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context 'when unauthorized' do
      it 'returns 403' do
        project = create(:project, public_builds: false)
        merge_request = create(:merge_request, :simple, source_project: project)
        guest = create(:user)
        project.add_guest(guest)

        get api("/projects/#{project.id}/merge_requests/#{merge_request.iid}/pipelines", guest)

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end

    context 'when merge request author has only guest access' do
      it_behaves_like 'rejects user from accessing merge request info' do
        let(:url) { "/projects/#{project.id}/merge_requests/#{merge_request.iid}/pipelines" }
      end
    end
  end

  describe 'GET :id/merge_requests/:merge_request_iid/closes_issues' do
    include_context 'with a merge request created once'

    it 'returns the issue that will be closed on merge' do
      group = create(:group, :public, developers: user)
      project_without_auto_close = create(:project, :public, group: group, autoclose_referenced_issues: false)
      group_issue = create(:issue, :group_level, namespace: group)
      no_close_issue = create(:issue, project: project_without_auto_close)
      issue = create(:issue, project: project)
      description = "Closes #{issue.to_reference(project)} " \
        "Closes #{group_issue.to_reference(project)} " \
        "Closes #{no_close_issue.to_reference(project)}"
      mr = create(:merge_request, :simple, author: user, source_project: project,
        target_project: project, description: description)

      get api("/projects/#{project.id}/merge_requests/#{mr.iid}/closes_issues", user)

      expect_successful_response_with_paginated_array
      expect(json_response.length).to eq(1)
      expect(json_response.first['id']).to eq(issue.id)
    end

    it 'returns an empty array when there are no issues to be closed' do
      get api("/projects/#{project.id}/merge_requests/#{merge_request.iid}/closes_issues", user)

      expect_empty_array_response
    end

    it 'handles external issues' do
      jira_project = create(:project, :with_jira_integration, :public, :repository, name: 'JIR_EXT1')
      ext_issue = ExternalIssue.new("#{jira_project.name}-123", jira_project)
      issue = create(:issue, project: jira_project)
      description = "Closes #{ext_issue.to_reference(jira_project)}\ncloses #{issue.to_reference}"
      merge_request = create(:merge_request,
        :simple, author: user, assignees: [user], source_project: jira_project, description: description)

      get api("/projects/#{jira_project.id}/merge_requests/#{merge_request.iid}/closes_issues", user)

      expect_successful_response_with_paginated_array
      expect(json_response.length).to eq(2)
      expect(json_response.second['title']).to eq(ext_issue.title)
      expect(json_response.second['id']).to eq(ext_issue.id)
      expect(json_response.second['confidential']).to be_nil
      expect(json_response.first['title']).to eq(issue.title)
      expect(json_response.first['id']).to eq(issue.id)
      expect(json_response.first['confidential']).not_to be_nil
    end

    it 'returns 403 if the user has no access to the merge request' do
      project = create(:project, :private)
      merge_request = create(:merge_request, :simple, source_project: project)
      guest = create(:user)
      project.add_guest(guest)

      get api("/projects/#{project.id}/merge_requests/#{merge_request.iid}/closes_issues", guest)

      expect(response).to have_gitlab_http_status(:forbidden)
    end

    it "returns 404 for an invalid merge request IID" do
      get api("/projects/#{project.id}/merge_requests/#{non_existing_record_iid}/closes_issues", user)

      expect(response).to have_gitlab_http_status(:not_found)
    end

    it "returns 404 if the merge request id is used instead of iid" do
      get api("/projects/#{project.id}/merge_requests/#{merge_request_id_not_used_as_iid}/closes_issues", user)

      expect(response).to have_gitlab_http_status(:not_found)
    end

    it_behaves_like 'authorizing granular token permissions', :read_merge_request_closes_issue do
      let(:boundary_object) { project }
      let(:request) do
        get api("/projects/#{project.id}/merge_requests/#{merge_request.iid}/closes_issues", personal_access_token: pat)
      end
    end
  end

  describe 'GET :id/merge_requests/:merge_request_iid/related_issues' do
    subject(:request) { get api("/projects/#{project.id}/merge_requests/#{mr_iid}/related_issues", requested_by) }

    let(:mr_iid) { merge_request.iid }
    let(:requested_by) { user }

    context 'when merge request does not reference any issue' do
      it 'returns an empty array' do
        request

        expect_empty_array_response
      end
    end

    context 'when merge request references issue in title' do
      let(:issue) { create(:issue, project: project) }

      before do
        merge_request.update!(title: "References #{issue.to_reference}")
      end

      it_behaves_like 'authorizing granular token permissions', :read_merge_request_related_issue do
        let(:boundary_object) { project }
        let(:request) do
          get api("/projects/#{project.id}/merge_requests/#{merge_request.iid}/related_issues",
            personal_access_token: pat)
        end
      end
    end

    context 'when merge request references external and internal issue in title' do
      let_it_be(:project) { create(:project, :with_jira_integration, :public, :repository, name: 'JIR_EXT1') }

      let(:external_issue) { ExternalIssue.new("#{project.name}-123", project) }
      let(:internal_issue) { create(:issue, project: project) }

      before do
        merge_request.update!(title: "References #{external_issue.to_reference} and #{internal_issue.to_reference}")
      end

      it 'returns external and internal issue' do
        request

        expect_successful_response_with_paginated_array
        expect(json_response.length).to eq(2)

        internal_issue_data = json_response.first
        expect(internal_issue_data['id']).to eq(internal_issue.id)
        expect(internal_issue_data['title']).to eq(internal_issue.title)
        expect(internal_issue_data).to have_key('confidential')

        external_issue_data = json_response.second
        expect(external_issue_data['id']).to eq(external_issue.id)
        expect(external_issue_data['title']).to eq(external_issue.title)
        expect(external_issue_data).not_to have_key('confidential')
      end
    end

    context 'when user has no access to the merge request' do
      let(:requested_by) { create(:user, guest_of: project) }

      before do
        project.update!(visibility_level: Gitlab::VisibilityLevel::PRIVATE)
      end

      it 'returns 403' do
        request

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end

    context 'when non-existing merge request iid provided' do
      let(:mr_iid) { non_existing_record_id }

      it 'returns 404' do
        request

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context 'when merge request id instead of iid provided' do
      let(:mr_iid) { merge_request_id_not_used_as_iid }

      it 'returns 404' do
        request

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end
  end
end
