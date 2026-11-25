# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RoutableActions, feature_category: :groups_and_projects do
  let_it_be(:project) { create(:project, :public) }
  let_it_be(:user) { create(:user) }

  before do
    login_as(user)
  end

  # The route constraint and the controller both resolve the project; the second lookup is
  # served by the query cache, so the recorder has to count cached queries too.
  def route_lookups(&request)
    recorder = ActiveRecord::QueryRecorder.new(skip_cached: false, &request)

    recorder.log.count { |query| query.include?('FROM "routes"') && query.include?('"routes"."path" =') }
  end

  def get_request
    get milestones_project_autocomplete_sources_path(project)
  end

  # The constraint stores the record with follow_redirects: false for a non-GET request, which is
  # the value find_routable! asks for there; a mismatch would silently fall back to a second lookup.
  def post_request
    post toggle_star_project_path(project)
  end

  it 'resolves the project once per request' do
    expect(route_lookups { get_request }).to eq(1)
    expect(response).to have_gitlab_http_status(:ok)
  end

  it 'resolves the project once per non-GET request' do
    expect(route_lookups { post_request }).to eq(1)
    expect(response).to have_gitlab_http_status(:ok)
  end

  context 'when the project was renamed' do
    let(:old_path) { "#{project.namespace.full_path}/old-path" }

    before do
      create(:redirect_route, source: project, path: old_path)
    end

    it 'still redirects to the canonical path' do
      get "/#{old_path}/-/autocomplete_sources/milestones"

      expect(response).to have_gitlab_http_status(:moved_permanently)
      expect(response).to redirect_to(milestones_project_autocomplete_sources_path(project))
    end
  end

  context 'when reuse_route_constraint_routable_lookup is disabled' do
    before do
      stub_feature_flags(reuse_route_constraint_routable_lookup: false)
    end

    it 'resolves the project twice' do
      expect(route_lookups { get_request }).to eq(2)
      expect(response).to have_gitlab_http_status(:ok)
    end

    it 'resolves the project twice on a non-GET request' do
      expect(route_lookups { post_request }).to eq(2)
      expect(response).to have_gitlab_http_status(:ok)
    end
  end
end
