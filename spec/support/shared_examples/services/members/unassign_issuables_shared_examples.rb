# frozen_string_literal: true

# Requires `group`, `requesting_user`, and two users with 3 assigned issuables each:
# `assignee_in_one_project` in a single project, and `assignee_in_several_projects` spread over 3 projects.
# Clears rate limits: the rate-limited work item broadcast reads `project_features` per issue when it runs.
RSpec.shared_examples 'unassigning without loading permissions per project', :clean_gitlab_redis_rate_limiting do
  it 'runs the same permission queries for one or several projects', :request_store do
    expect_same_permission_queries
  end

  context 'when access levels come from project authorizations' do
    before do
      stub_feature_flags(resolve_project_access_from_memberships: false)
    end

    it 'runs the same permission queries for one or several projects', :request_store do
      expect_same_permission_queries
    end
  end

  def expect_same_permission_queries
    one_project_count = permission_query_count(assignee_in_one_project)

    expect(one_project_count).to be_positive
    expect(permission_query_count(assignee_in_several_projects)).to eq(one_project_count)
  end

  def permission_query_count(user)
    service = described_class.new(user, group, requesting_user)

    RequestStore.clear!
    recorder = ActiveRecord::QueryRecorder.new { service.execute }
    recorder.log.count do |query|
      query.match?(/FROM "(members|project_group_links|organizations|project_authorizations|project_features)"/)
    end
  end
end
