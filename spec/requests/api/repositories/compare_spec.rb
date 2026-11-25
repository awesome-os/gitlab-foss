# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::Repositories, feature_category: :source_code_management do
  include RepoHelpers
  include ProjectForksHelper

  let_it_be(:user) { create(:user) }
  let_it_be(:project, reload: true) { create(:project, :repository, creator: user) }
  let!(:maintainer) { create(:project_member, :maintainer, user: user, project: project) }
  let(:guest) { create(:user).tap { |u| create(:project_member, :guest, user: u, project: project) } }
  let(:developer) { create(:user).tap { |u| create(:project_member, :developer, user: u, project: project) } }

  describe 'GET /projects/:id/repository/compare' do
    let(:route) { "/projects/#{project.id}/repository/compare" }

    shared_examples_for 'repository compare' do
      include_context 'for workhorse body uploads'

      it "compares branches" do
        expect(::Gitlab::Git::Compare).to receive(:new).with(anything, anything, anything, {
          straight: false
        }).and_call_original
        get api(route, current_user), params: { from: 'master', to: 'feature' }

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response['commits']).to be_present
        expect(json_response['diffs']).to be_present
        expect(json_response['web_url']).to be_present
        expect(json_response['web_url']).to include('...')
      end

      it "compares branches with explicit merge-base mode" do
        expect(::Gitlab::Git::Compare).to receive(:new).with(anything, anything, anything, {
          straight: false
        }).and_call_original
        get api(route, current_user), params: { from: 'master', to: 'feature', straight: false }

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response['commits']).to be_present
        expect(json_response['diffs']).to be_present
        expect(json_response['web_url']).to be_present
        expect(json_response['web_url']).to include('...')
      end

      it "compares branches with explicit straight mode" do
        expect(::Gitlab::Git::Compare).to receive(:new).with(anything, anything, anything, {
          straight: true
        }).and_call_original
        get api(route, current_user), params: { from: 'master', to: 'feature', straight: true }

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response['commits']).to be_present
        expect(json_response['diffs']).to be_present
        expect(json_response['web_url']).to be_present
        expect(json_response['web_url']).to include('..').and exclude('...')
      end

      it "compares tags" do
        get api(route, current_user), params: { from: 'v1.0.0', to: 'v1.1.0' }

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response['commits']).to be_present
        expect(json_response['diffs']).to be_present
        expect(json_response['web_url']).to be_present
      end

      it "compares commits" do
        get api(route, current_user), params: { from: sample_commit.id, to: sample_commit.parent_id }

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response['commits']).to be_empty
        expect(json_response['diffs']).to be_empty
        expect(json_response['compare_same_ref']).to be_falsey
        expect(json_response['web_url']).to be_present
      end

      it "compares commits in reverse order" do
        get api(route, current_user), params: { from: sample_commit.parent_id, to: sample_commit.id }

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response['commits']).to be_present
        expect(json_response['diffs']).to be_present
        expect(json_response['web_url']).to be_present
      end

      it "compare commits between different projects with non-forked relation" do
        public_project = create(:project, :repository, :public)

        get api(route, current_user), params: { from: sample_commit.parent_id, to: sample_commit.id, from_project_id: public_project.id }

        expect(response).to have_gitlab_http_status(:bad_request)
      end

      it "compare commits between different projects" do
        group = create(:group)
        group.add_owner(current_user) if current_user

        forked_project = fork_project(project, current_user, repository: true, namespace: group)
        forked_project.repository.create_ref('refs/heads/improve/awesome', 'refs/heads/improve/more-awesome')

        get api(route, current_user), params: { from: 'improve/awesome', to: 'feature', from_project_id: forked_project.id }

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response['commits']).to be_present
        expect(json_response['diffs']).to be_present
      end

      it "compares same refs" do
        get api(route, current_user), params: { from: 'master', to: 'master' }

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response['commits']).to be_empty
        expect(json_response['diffs']).to be_empty
        expect(json_response['compare_same_ref']).to be_truthy
      end

      it "requests the diff from Gitaly once" do
        expect(Gitlab::Git::Diff).to receive(:between).once.and_call_original

        get api(route, current_user), params: { from: 'master', to: 'feature' }

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response['diffs']).to be_present
        expect(json_response['compare_timeout']).to be(false)
      end

      context 'when unidiff format is requested' do
        let(:commit) { project.repository.commit('feature') }
        let(:diff) { commit.diffs.diffs.first }

        it 'returns a diff in Unified format' do
          get api(route, current_user), params: { from: 'master', to: 'feature', unidiff: true }

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response.dig('diffs', 0, 'diff')).to eq(diff.unidiff)
        end
      end

      it "returns an empty string when the diff overflows" do
        allow(Gitlab::Git::DiffCollection)
          .to receive(:default_limits)
          .and_return({ max_files: 2, max_lines: 2 })

        get api(route, current_user), params: { from: 'master', to: 'feature' }

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response['commits']).to be_present
        expect(json_response['diffs']).to be_present
        expect(json_response['diffs'].first['diff']).to be_empty
      end

      it "returns a 404 when from ref is unknown" do
        get api(route, current_user), params: { from: 'unknown_ref', to: 'master' }

        expect(response).to have_gitlab_http_status(:not_found)
      end

      it "returns a 404 when to ref is unknown" do
        get api(route, current_user), params: { from: 'master', to: 'unknown_ref' }

        expect(response).to have_gitlab_http_status(:not_found)
      end

      # Grape's `requires` only checks the key exists, so a bare `?from&to=...` reaches the endpoint as nil.
      it "returns a 404 when from ref is empty" do
        get api("#{route}?from&to=master", current_user)

        expect(response).to have_gitlab_http_status(:not_found)
      end

      it "returns a newly created commit", :use_clean_rails_redis_caching do
        # Parse the commits ourselves because json_response is cached
        def commit_messages(response)
          Gitlab::Json.parse(response.body)["commits"].map do |commit|
            commit["message"]
          end
        end

        # First trigger the rate limit cache
        get api(route, current_user), params: { from: 'master', to: 'feature' }

        expect(response).to have_gitlab_http_status(:ok)
        expect(commit_messages(response)).not_to include("Cool new commit")

        # Then create a new commit via the API
        url = api("/projects/#{project.id}/repository/commits", user)
        params =  {
          branch: "feature",
          commit_message: "Cool new commit",
          actions: [
            {
              action: "create",
              file_path: "foo/bar/baz.txt",
              content: "puts 8"
            }
          ]
        }
        perform_workhorse_json_body_upload(url, params.to_json)

        expect(response).to have_gitlab_http_status(:created)

        # Now perform the same query as before, but the cache should have expired
        # and our new commit should exist
        get api(route, current_user), params: { from: 'master', to: 'feature' }

        expect(response).to have_gitlab_http_status(:ok)
        expect(commit_messages(response)).to include("Cool new commit")
      end
    end

    context 'when unauthenticated', 'and project is public' do
      it_behaves_like 'repository compare' do
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
      it_behaves_like 'repository compare' do
        let(:project) { create(:project, :repository, creator: user) }
        let(:current_user) { user }

        context 'when user does not have read access to the parent project' do
          let_it_be(:group) { create(:group) }
          let(:forked_project) { fork_project(project, current_user, repository: true, namespace: group) }

          before do
            forked_project.add_guest(current_user)
          end

          it 'returns 403 error' do
            get api(route, current_user), params: { from: 'improve/awesome', to: 'feature', from_project_id: forked_project.id }

            expect(response).to have_gitlab_http_status(:forbidden)
            expect(json_response['message']).to eq("403 Forbidden - You don't have access to this fork's parent project")
          end
        end
      end
    end

    context 'when authenticated', 'as a guest' do
      it_behaves_like '403 response' do
        let(:request) { get api(route, guest) }
      end
    end

    describe 'response caching', :use_clean_rails_redis_caching do
      let_it_be(:public_project) { create(:project, :public, :repository, creator: user) }
      let(:route) { "/projects/#{public_project.id}/repository/compare" }

      def compare_commit_ids(response)
        Gitlab::Json.parse(response.body)['commits'].map { |commit| commit['id'] }
      end

      it 'shares the cached response between requesters' do
        expect(Gitlab::Git::Diff).to receive(:between).once.and_call_original

        get api(route, user), params: { from: 'master', to: 'feature' }
        first = compare_commit_ids(response)

        get api(route, developer), params: { from: 'master', to: 'feature' }

        expect(response).to have_gitlab_http_status(:ok)
        expect(compare_commit_ids(response)).to eq(first)
      end

      it 'shares the cached response between spellings of the same ref' do
        expect(Gitlab::Git::Diff).to receive(:between).once.and_call_original

        get api(route, user), params: { from: 'master', to: 'feature' }
        first = compare_commit_ids(response)

        get api(route, user), params: { from: 'master', to: public_project.commit('feature').sha }

        expect(response).to have_gitlab_http_status(:ok)
        expect(compare_commit_ids(response)).to eq(first)
      end

      it 'does not share the cached response between comparison modes' do
        expect(Gitlab::Git::Diff).to receive(:between).twice.and_call_original

        get api(route, user), params: { from: 'master', to: 'feature' }
        get api(route, user), params: { from: 'master', to: 'feature', straight: true }

        expect(response).to have_gitlab_http_status(:ok)
      end

      it 'does not share the cached response between diff formats' do
        expect(Gitlab::Git::Diff).to receive(:between).twice.and_call_original

        get api(route, user), params: { from: 'master', to: 'feature' }
        get api(route, user), params: { from: 'master', to: 'feature', unidiff: true }

        expect(response).to have_gitlab_http_status(:ok)
      end

      it 'does not cache a request with a padded ref' do
        expect(Gitlab::Git::Diff).to receive(:between).twice.and_call_original

        get api(route, user), params: { from: 'master', to: ' feature' }
        get api(route, user), params: { from: 'master', to: ' feature' }

        expect(response).to have_gitlab_http_status(:ok)
      end

      it 'does not serve a cached response to a request with a missing ref' do
        get api(route, user), params: { from: 'master', to: 'feature' }
        expect(response).to have_gitlab_http_status(:ok)

        get api("#{route}?from&to=feature", user)

        expect(response).to have_gitlab_http_status(:not_found)
      end

      context 'with the anonymous commits limit' do
        let(:params) { { from: 'master', to: 'few-commits' } }
        let(:all_commit_ids) { public_project.repository.commits_between('master', 'few-commits').map(&:id) }

        before do
          stub_const('MergeRequestDiff::COMMITS_SAFE_SIZE', 2)
        end

        it 'does not serve a capped anonymous response to an authenticated caller' do
          get api(route), params: params
          expect(compare_commit_ids(response).size).to eq(2)

          get api(route, user), params: params

          expect(response).to have_gitlab_http_status(:ok)
          expect(compare_commit_ids(response)).to match_array(all_commit_ids)
        end

        it 'does not serve a full authenticated response to an anonymous caller' do
          get api(route, user), params: params
          expect(compare_commit_ids(response)).to match_array(all_commit_ids)

          get api(route), params: params

          expect(response).to have_gitlab_http_status(:ok)
          expect(compare_commit_ids(response)).to eq(all_commit_ids.last(2))
        end
      end
    end

    describe 'anonymous commits limit' do
      let_it_be(:public_project) { create(:project, :public, :repository, creator: user) }
      let(:route) { "/projects/#{public_project.id}/repository/compare" }
      let(:params) { { from: 'master', to: 'few-commits' } }
      let(:all_commit_ids) { public_project.repository.commits_between('master', 'few-commits').map(&:id) }

      before do
        stub_const('MergeRequestDiff::COMMITS_SAFE_SIZE', 2)
      end

      # commits_between is chronological, so the newest two are its last two, in the same order.
      it 'returns the newest commits in chronological order to unauthenticated callers' do
        get api(route), params: params

        expect(response).to have_gitlab_http_status(:ok)
        expect(all_commit_ids.size).to be > 2
        expect(json_response['commits'].pluck('id')).to eq(all_commit_ids.last(2))
        expect(json_response['commit']['id']).to eq(all_commit_ids.last)
      end

      it 'requests the commits from Gitaly once' do
        expect(Gitlab::Git::Commit).to receive(:between).once.and_call_original

        get api(route), params: params

        expect(response).to have_gitlab_http_status(:ok)
      end

      it 'does not cap the commits returned to authenticated callers' do
        get api(route, user), params: params

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response['commits'].map { |commit| commit['id'] }).to match_array(all_commit_ids)
      end

      context 'when the compare_api_anonymous_commits_limit feature flag is disabled' do
        before do
          stub_feature_flags(compare_api_anonymous_commits_limit: false)
        end

        it 'does not cap the commits returned to unauthenticated callers' do
          get api(route), params: params

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response['commits'].map { |commit| commit['id'] }).to match_array(all_commit_ids)
        end
      end
    end

    describe 'Gitaly timeouts', :use_clean_rails_redis_caching do
      let(:params) { { from: 'master', to: 'feature' } }

      # The diff stream is read lazily while the entity renders, outside wrapped_gitaly_errors,
      # so a real deadline surfaces as GRPC::DeadlineExceeded from the stitcher.
      def stub_diff_timeout
        allow_next_instance_of(Gitlab::GitalyClient::DiffStitcher) do |stitcher|
          allow(stitcher).to receive(:each).and_raise(GRPC::DeadlineExceeded, 'deadline exceeded')
        end
      end

      def restore_diff
        allow(Gitlab::GitalyClient::DiffStitcher).to receive(:new).and_call_original
      end

      it 'returns 503 with a Retry-After header when the diff times out', :freeze_time do
        stub_diff_timeout

        get api(route, user), params: params

        expect(response).to have_gitlab_http_status(:service_unavailable)
        expect(response.headers['Retry-After'].to_i).to eq(API::Repositories::COMPARE_TIMED_OUT_EXPIRY.to_i)
      end

      it 'also handles a wrapped timeout' do
        allow(Gitlab::Git::Diff).to receive(:between).and_raise(Gitlab::Git::CommandTimedOut, 'deadline exceeded')

        get api(route, user), params: params

        expect(response).to have_gitlab_http_status(:service_unavailable)
      end

      it 'does not ask Gitaly again for the same range within the expiry' do
        stub_diff_timeout
        get api(route, user), params: params

        expect(Gitlab::Git::Diff).not_to receive(:between)

        travel_to(3.minutes.from_now) do
          get api(route, developer), params: { from: 'master', to: project.commit('feature').sha }
        end

        expect(response).to have_gitlab_http_status(:service_unavailable)
        expect(response.headers['Retry-After'].to_i).to be_between(1, 7.minutes.to_i)
      end

      # Uncached requests render the entity after the endpoint block, so the timeout handling cannot apply.
      it 'leaves a request that bypasses the cache unchanged and records no marker' do
        stub_diff_timeout
        get api(route, user), params: { from: 'master', to: ' feature' }
        expect(response).to have_gitlab_http_status(:internal_server_error)

        restore_diff

        get api(route, user), params: params

        expect(response).to have_gitlab_http_status(:ok)
      end

      it 'asks Gitaly again once the expiry has passed' do
        stub_diff_timeout
        get api(route, user), params: params

        travel_to(API::Repositories::COMPARE_TIMED_OUT_EXPIRY.from_now + 1.second) do
          restore_diff

          get api(route, user), params: params

          expect(response).to have_gitlab_http_status(:ok)
        end
      end

      it 'keeps a different range of the same project out of the timeout' do
        stub_diff_timeout
        get api(route, user), params: params

        restore_diff

        get api(route, user), params: { from: 'master', to: 'few-commits' }

        expect(response).to have_gitlab_http_status(:ok)
      end

      it 'does not remember a timeout from a straight comparison for the merge-base one' do
        stub_diff_timeout
        get api(route, user), params: params.merge(straight: true)

        restore_diff

        get api(route, user), params: params

        expect(response).to have_gitlab_http_status(:ok)
      end

      context 'when the compare_api_diff_timeout_cache feature flag is disabled' do
        before do
          stub_feature_flags(compare_api_diff_timeout_cache: false)
        end

        it 'surfaces the timeout as before and retries Gitaly on the next request' do
          stub_diff_timeout
          get api(route, user), params: params

          expect(response).to have_gitlab_http_status(:internal_server_error)
          expect(json_response['message']).to include('deadline exceeded')
          expect(response.headers['Retry-After']).to be_nil

          expect(Gitlab::Git::Diff).to receive(:between).once.and_call_original

          get api(route, user), params: params

          expect(response).to have_gitlab_http_status(:internal_server_error)
        end
      end
    end

    describe 'rate limiting' do
      let_it_be(:public_project) { create(:project, :public, :repository, creator: user) }
      let(:public_route) { "/projects/#{public_project.id}/repository/compare" }
      let(:params) { { from: 'master', to: 'feature' } }

      context 'when authenticated' do
        it_behaves_like 'rate limited endpoint', rate_limit_key: :project_repositories_compare do
          let(:current_user) { user }

          def request
            get api(route, current_user), params: params
          end

          # The limit is per user, so a second user is a second scope.
          def request_with_second_scope
            get api(route, developer), params: params
          end
        end
      end

      context 'when unauthenticated' do
        it_behaves_like 'rate limited endpoint',
          rate_limit_key: :project_repositories_compare_unauthenticated, use_second_scope: false do
          let(:current_user) { nil }

          def request
            get api(public_route), params: params
          end
        end
      end

      context 'with the limits applied', :clean_gitlab_redis_rate_limiting do
        before do
          stub_application_setting(
            project_repositories_compare_limit: 1,
            project_repositories_compare_unauthenticated_limit: 1
          )
        end

        it 'throttles a second anonymous request from the same IP', :aggregate_failures do
          get api(public_route), params: params
          expect(response).to have_gitlab_http_status(:ok)

          get api(public_route), params: params
          expect(response).to have_gitlab_http_status(:too_many_requests)
        end

        it 'does not charge an anonymous request to the authenticated limit', :aggregate_failures do
          get api(public_route), params: params
          expect(response).to have_gitlab_http_status(:ok)

          get api(public_route, user), params: params
          expect(response).to have_gitlab_http_status(:ok)
        end

        it 'counts a user across projects', :aggregate_failures do
          get api(route, user), params: params
          expect(response).to have_gitlab_http_status(:ok)

          get api(public_route, user), params: params
          expect(response).to have_gitlab_http_status(:too_many_requests)
        end

        # The throttle must run before the comparison, not merely short-circuit the response.
        it 'does not compare once throttled', :aggregate_failures do
          get api(route, user), params: params
          expect(response).to have_gitlab_http_status(:ok)

          expect(CompareService).not_to receive(:new)

          get api(route, user), params: params
          expect(response).to have_gitlab_http_status(:too_many_requests)
        end

        context 'when the compare_api_rate_limit feature flag is disabled' do
          before do
            stub_feature_flags(compare_api_rate_limit: false)
          end

          it 'does not throttle', :aggregate_failures do
            expect(Gitlab::ApplicationRateLimiter).not_to receive(:throttled?)

            get api(route, user), params: params
            get api(route, user), params: params

            expect(response).to have_gitlab_http_status(:ok)
          end
        end
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
