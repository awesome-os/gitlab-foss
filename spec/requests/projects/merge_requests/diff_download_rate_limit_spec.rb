# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Merge request .diff and .patch download rate limit', :freeze_time,
  :clean_gitlab_redis_rate_limiting, feature_category: :code_review_workflow do
  let_it_be(:user) { create(:user) }
  let_it_be(:other_user) { create(:user) }
  let_it_be(:project) { create(:project, :public, :repository) }
  let_it_be(:merge_request) { create(:merge_request, source_project: project) }
  let_it_be(:other_project) { create(:project, :public, :repository) }
  let_it_be(:other_merge_request) { create(:merge_request, source_project: other_project) }

  let(:send_data_header) { Gitlab::Workhorse::SEND_DATA_HEADER }
  let(:ip) { '203.0.113.1' }
  let(:other_ip) { '203.0.113.2' }
  let(:log_state) { 'applimiter_merge_request_diff_download:limit_mr_diff_downloads_by_user_or_ip_log' }

  before do
    stub_application_setting(merge_request_diff_download_request_limit: 1)
  end

  shared_examples 'a rate limited diff download' do
    def download(merge_request, from: ip)
      get download_path(merge_request), env: { 'REMOTE_ADDR' => from }
    end

    context 'when anonymous' do
      it 'returns 429 once the IP address is over the limit, without the Workhorse header', :aggregate_failures do
        download(merge_request)

        expect(response).to have_gitlab_http_status(:ok)
        expect(response.headers[send_data_header]).to be_present

        download(merge_request)

        expect(response).to have_gitlab_http_status(:too_many_requests)
        expect(response.headers[send_data_header]).to be_nil
      end

      it 'counts every project against the same IP address bucket' do
        download(merge_request)
        download(other_merge_request)

        expect(response).to have_gitlab_http_status(:too_many_requests)
      end

      it 'does not count requests from another IP address' do
        download(merge_request)
        download(merge_request, from: other_ip)

        expect(response).to have_gitlab_http_status(:ok)
      end

      it 'counts against the IP address' do
        expect(Gitlab::ApplicationRateLimiter).to receive(:throttled_request?)
          .with(anything, nil, :merge_request_diff_download, scope: { ip: ip })
          .and_call_original

        download(merge_request)
      end

      context 'when the merge_request_diff_download_rate_limit feature flag is disabled' do
        before do
          stub_feature_flags(merge_request_diff_download_rate_limit: false)
        end

        it 'logs the requests over the limit without blocking them', :aggregate_failures do
          states = track_rate_limit_states('applimiter_merge_request_diff_download')

          2.times do
            download(merge_request)

            expect(response).to have_gitlab_http_status(:ok)
          end

          expect(states).to eq(["#{log_state}:allow", "#{log_state}:log"])
        end
      end
    end

    context 'when signed in' do
      before do
        sign_in(user)
      end

      it 'returns 429 once the user is over the limit, without the Workhorse header', :aggregate_failures do
        download(merge_request)

        expect(response).to have_gitlab_http_status(:ok)

        download(other_merge_request, from: other_ip)

        expect(response).to have_gitlab_http_status(:too_many_requests)
        expect(response.headers[send_data_header]).to be_nil
      end

      it 'does not count requests from another user on the same IP address' do
        download(merge_request)

        sign_in(other_user)
        download(merge_request)

        expect(response).to have_gitlab_http_status(:ok)
      end

      it 'counts against the user, not the IP address' do
        expect(Gitlab::ApplicationRateLimiter).to receive(:throttled_request?)
          .with(anything, user, :merge_request_diff_download, scope: { user: user })
          .and_call_original

        download(merge_request)
      end

      context 'when the merge_request_diff_download_rate_limit feature flag is disabled' do
        before do
          stub_feature_flags(merge_request_diff_download_rate_limit: false)
        end

        it 'logs the requests over the limit without blocking them', :aggregate_failures do
          states = track_rate_limit_states('applimiter_merge_request_diff_download')

          2.times do
            download(merge_request)

            expect(response).to have_gitlab_http_status(:ok)
          end

          expect(states).to eq(["#{log_state}:allow", "#{log_state}:log"])
        end
      end
    end
  end

  describe 'GET /-/merge_requests/:id.diff' do
    def download_path(merge_request)
      project_merge_request_path(merge_request.project, merge_request, format: :diff)
    end

    it_behaves_like 'a rate limited diff download'
  end

  describe 'GET /-/merge_requests/:id.patch' do
    def download_path(merge_request)
      project_merge_request_path(merge_request.project, merge_request, format: :patch)
    end

    it_behaves_like 'a rate limited diff download'
  end

  describe 'GET /-/merge_requests/:id/diffs.diff' do
    def download_path(merge_request)
      "/#{merge_request.project.full_path}/-/merge_requests/#{merge_request.iid}/diffs.diff"
    end

    it_behaves_like 'a rate limited diff download'
  end

  describe 'GET /-/merge_requests/:id/diffs.patch' do
    def download_path(merge_request)
      "/#{merge_request.project.full_path}/-/merge_requests/#{merge_request.iid}/diffs.patch"
    end

    it_behaves_like 'a rate limited diff download'
  end

  describe 'GET /-/merge_requests/:id/reports.diff' do
    def download_path(merge_request)
      "/#{merge_request.project.full_path}/-/merge_requests/#{merge_request.iid}/reports.diff"
    end

    it_behaves_like 'a rate limited diff download'
  end

  describe 'GET /-/merge_requests/:id/reports.patch' do
    def download_path(merge_request)
      "/#{merge_request.project.full_path}/-/merge_requests/#{merge_request.iid}/reports.patch"
    end

    it_behaves_like 'a rate limited diff download'
  end

  describe 'GET /-/merge_requests/:id/reports/*vueroute.patch' do
    def download_path(merge_request)
      "/#{merge_request.project.full_path}/-/merge_requests/#{merge_request.iid}/reports/security.patch"
    end

    it_behaves_like 'a rate limited diff download'
  end

  describe 'other formats' do
    before do
      allow(Gitlab::ApplicationRateLimiter).to receive(:throttled_request?).and_call_original
    end

    it 'does not count the HTML merge request page' do
      expect(Gitlab::ApplicationRateLimiter).not_to receive(:throttled_request?)
        .with(anything, anything, :merge_request_diff_download, anything)

      get project_merge_request_path(project, merge_request)

      expect(response).to have_gitlab_http_status(:ok)
    end

    it 'does not count the JSON merge request' do
      expect(Gitlab::ApplicationRateLimiter).not_to receive(:throttled_request?)
        .with(anything, anything, :merge_request_diff_download, anything)

      get project_merge_request_path(project, merge_request, format: :json)

      expect(response).to have_gitlab_http_status(:ok)
    end

    it 'does not count the JSON diffs' do
      expect(Gitlab::ApplicationRateLimiter).not_to receive(:throttled_request?)
        .with(anything, anything, :merge_request_diff_download, anything)

      get diffs_project_merge_request_path(project, merge_request, format: :json)

      expect(response).to have_gitlab_http_status(:ok)
    end
  end

  # RequestStore::Middleware clears the store when the request ends, so read the state while it runs.
  def track_rate_limit_states(limiter_name)
    states = []
    allow(Gitlab::Instrumentation::RateLimitState).to receive(:track).and_wrap_original do |original, results|
      original.call(results)
      next unless results.key?(limiter_name)

      states << Gitlab::Instrumentation::RateLimitState.payload[:rate_limit_state].last
    end

    states
  end
end
