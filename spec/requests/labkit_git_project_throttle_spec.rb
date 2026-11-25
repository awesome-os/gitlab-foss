# frozen_string_literal: true

require 'spec_helper'

# End-to-end proof that the per-project Git rate limit override is enforced by the
# Labkit stack once every cohort shadows and enforces, when Gitlab::RackAttack
# safelists every request.
RSpec.describe 'per-project Git throttle enforced through Labkit',
  :clean_gitlab_redis_rate_limiting, feature_category: :rate_limiting do
  include RackAttackSpecHelpers

  let_it_be(:project, refind: true) { create(:project, :repository, :public) }
  let_it_be(:other_project, refind: true) { create(:project, :repository, :public) }
  let_it_be(:user) { create(:user) }
  let_it_be(:token) { create(:personal_access_token, user: user) }

  let(:instance_limit) { 3 }
  let(:project_limit) { 1 }

  let(:headers) do
    WorkhorseHelpers.workhorse_internal_api_request_header.merge(basic_auth_headers(user, token))
  end

  def clone_request(target)
    get "/#{target.full_path}.git/info/refs?service=git-upload-pack", headers: headers
  end

  around do |example|
    freeze_time { example.run }
  end

  before do
    # Both are suite-wide defaults today, but this file's whole premise is that
    # they hold; without them a subset of the examples would still pass and the
    # file would read as a flake rather than a failure.
    stub_feature_flags(project_git_throttle_overrides: true)
    Gitlab::RackAttack::LabkitRateLimit::Limiters.reset!

    Gitlab::RackAttack::LabkitRateLimit::ThrottleRegistry.cohorts.each do |cohort|
      stub_feature_flags(
        "rate_limiter_use_labkit_rack_cohort_#{cohort}": true,
        "rate_limiter_use_labkit_rack_cohort_#{cohort}_enforce": true
      )
    end

    stub_application_setting(
      throttle_authenticated_git_http_enabled: true,
      throttle_authenticated_git_http_requests_per_period: instance_limit,
      throttle_authenticated_git_http_period_in_seconds: 60
    )

    project.project_setting.update!(throttle_authenticated_git_http_requests_per_period: project_limit)
    Gitlab::RateLimit::ProjectThrottleLimits.expire!
  end

  after do
    Gitlab::RateLimit::ProjectThrottleLimits.expire!
    Gitlab::RackAttack::LabkitRateLimit::Limiters.reset!
  end

  it 'has every cohort fully enforced, so Rack::Attack is safelisted' do
    expect(Gitlab::RackAttack::LabkitRateLimit::ThrottleRegistry).to be_fully_enforced
  end

  # Both stacks emit a byte-identical 429, so the status alone does not say which
  # one answered. The rule name does, and only Labkit sets it.
  it 'names the Labkit per-project rule on the rejection' do
    clone_request(project)
    clone_request(project)

    expect(response).to have_gitlab_http_status(:too_many_requests)
    expect(response.headers['RateLimit-Name']).to eq('throttle_authenticated_git_http_project')
    expect(response.headers['RateLimit-Limit']).to eq(project_limit.to_s)
  end

  it 'throttles the overridden project at its own limit, below the instance one' do
    expect(project_limit).to be < instance_limit

    project_limit.times do
      clone_request(project)
      expect(response).to have_gitlab_http_status(:ok)
    end

    clone_request(project)
    expect(response).to have_gitlab_http_status(:too_many_requests)
  end

  it 'leaves a project without an override on the instance limit' do
    instance_limit.times do
      clone_request(other_project)
      expect(response).to have_gitlab_http_status(:ok)
    end

    clone_request(other_project)
    expect(response).to have_gitlab_http_status(:too_many_requests)
  end

  # The override adds a counter rather than replacing one, so traffic to the
  # overridden project still spends the actor's instance-wide budget. Without
  # that, owning N projects would buy N budgets.
  it 'still counts an overridden project against the instance-wide counter' do
    clone_request(project)
    expect(response).to have_gitlab_http_status(:ok)

    # Two more on a project with no override: the instance counter is now at its
    # limit because the request above counted there too.
    (instance_limit - 1).times do
      clone_request(other_project)
      expect(response).to have_gitlab_http_status(:ok)
    end

    clone_request(other_project)
    expect(response).to have_gitlab_http_status(:too_many_requests)
  end

  # Git HTTP keeps serving a project's pre-rename paths. Both paths have to spend
  # the same budget, or an actor gets a fresh one per rename the project has had.
  context 'when the project has been renamed' do
    # Eager, so it is the pre-rename path rather than the post-rename one.
    let!(:old_path) { project.full_path }

    before do
      project.update!(path: "#{project.path}-renamed")
      Gitlab::RateLimit::ProjectThrottleLimits.expire!
    end

    it 'spends one budget across the old and the new path' do
      get "/#{old_path}.git/info/refs?service=git-upload-pack", headers: headers
      expect(response).to have_gitlab_http_status(:ok)

      get "/#{project.reload.full_path}.git/info/refs?service=git-upload-pack", headers: headers
      expect(response).to have_gitlab_http_status(:too_many_requests)
      expect(response.headers['RateLimit-Name']).to eq('throttle_authenticated_git_http_project')
    end
  end

  context 'when only LFS is overridden' do
    before do
      project.project_setting.update!(
        throttle_authenticated_git_http_requests_per_period: nil,
        throttle_authenticated_git_lfs_requests_per_period: project_limit
      )
      Gitlab::RateLimit::ProjectThrottleLimits.expire!
    end

    it 'leaves Git HTTP on the instance limit' do
      instance_limit.times do
        clone_request(project)
        expect(response).to have_gitlab_http_status(:ok)
      end

      clone_request(project)
      expect(response).to have_gitlab_http_status(:too_many_requests)
    end
  end
end
