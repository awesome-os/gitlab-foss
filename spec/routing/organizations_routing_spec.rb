# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Organization routes', feature_category: :organization do
  describe 'organization-prefixed routes' do
    it 'handles routes with /o/:organization_path prefix' do
      expect(get('/o/my-org')).to be_routable
    end

    it 'includes organization_path parameter in routed params' do
      expect(get('/o/my-org')).to route_to('root#index', organization_path: 'my-org')
    end

    it 'ensures organization_path is constrained' do
      expect(get('/o/admin/projects/new')).to route_to_route_not_found
    end
  end

  # The key of an etag-cached endpoint is its request path, so a second URL for
  # one resource would give the poller and the code that invalidates it two
  # different keys. See doc/development/polling.md.
  describe 'endpoints polled with etag caching' do
    # Asserted by endpoint rather than with `be_routable`, which the
    # `/*unmatched_route` catch-all satisfies for any string.
    {
      '/import/github/realtime_changes' => 'import/github#realtime_changes',
      '/import/bitbucket/realtime_changes' => 'import/bitbucket#realtime_changes',
      '/import/bitbucket_server/realtime_changes' => 'import/bitbucket_server#realtime_changes',
      '/import/gitea/realtime_changes' => 'import/gitea#realtime_changes'
    }.each do |path, endpoint|
      it "serves #{path} but not its organization-scoped form" do
        expect(get(path)).to route_to(endpoint)
        expect(get("/o/my-org#{path}")).to route_to_route_not_found
      end
    end

    # Reads the CE constant, not `all_routes`, so the expectation holds in FOSS
    # too. Matched by endpoint because these regexps share an interpolated
    # prefix, so their source cannot tell the two kinds apart.
    it 'covers every etag route that does not address a group or a project' do
      scoped = ::Gitlab::EtagCaching::Router::Rails::ROUTES.reject do |route|
        route.caller_id.start_with?('Projects::', 'Groups::')
      end

      expect(scoped.map(&:name)).to match_array(
        %w[
          realtime_changes_import_github realtime_changes_import_bitbucket
          realtime_changes_import_gitea realtime_changes_import_bitbucket_server
        ]
      )
    end
  end

  describe 'excluded routes from organization routing' do
    RSpec.shared_examples 'organization route exclusion' do |route_path|
      describe "route exclusion for #{route_path}" do
        it 'does not route through organization scoped paths' do
          expect(get(route_path)).to route_to_route_not_found
        end
      end
    end

    context 'for api routes' do
      it_behaves_like 'organization route exclusion', '/o/my-org/api/v4/projects'
      it_behaves_like 'organization route exclusion', '/o/my-org/api/graphql'
      it_behaves_like 'organization route exclusion', '/o/my-org/api/glql'
    end

    # Groups, projects and users are drawn once. A record in a non-default
    # organization carries `o/<org>/` inside its own route path instead. Their
    # former cloned URLs redirect; see the organization request specs.
    context 'for routable id redirects' do
      it_behaves_like 'organization route exclusion', '/o/my-org/-/g/1'
      it_behaves_like 'organization route exclusion', '/o/my-org/-/p/1'
      it_behaves_like 'organization route exclusion', '/o/my-org/-/u/1'
      it_behaves_like 'organization route exclusion', '/o/my-org/projects/1'
    end
  end

  describe 'organization-prefixed routable paths' do
    let(:url_helpers) { Rails.application.routes.url_helpers }

    it 'recognizes a prefixed group path as the group itself' do
      allow(Group).to receive(:find_by_full_path).with('o/my-org/gitlabhq', any_args).and_return(true)

      expect(get('/o/my-org/gitlabhq')).to route_to('groups#show', id: 'o/my-org/gitlabhq')
    end

    it 'recognizes a prefixed project path as the project itself' do
      allow(Project).to receive(:find_by_full_path).with('o/my-org/gitlabhq/gitlab', any_args).and_return(true)

      expect(get('/o/my-org/gitlabhq/gitlab/-/issues'))
        .to route_to('projects/issues#index', namespace_id: 'o/my-org/gitlabhq', project_id: 'gitlab')
    end

    it 'generates group and project URLs from prefixed paths' do
      project_path = url_helpers.namespace_project_path(namespace_id: 'o/my-org/gitlabhq', id: 'gitlab')

      expect(url_helpers.group_path(id: 'o/my-org/gitlabhq')).to eq('/o/my-org/gitlabhq')
      expect(project_path).to eq('/o/my-org/gitlabhq/gitlab')
    end
  end

  # Routable resources are drawn once: the organization prefix lives inside their
  # own route path. A clone that survives under /o/ shadows the redirect to the
  # canonical URL, which is how the EE user template routes stayed scoped.
  describe 'routable resources are not cloned under /o/' do
    # Controllers that identify a group, project or user by its path, and the
    # parameters they read that path from.
    routable_controllers = %w[groups projects users namespaces].freeze
    routable_prefixes = %w[groups/ projects/ repositories/].freeze
    routable_parts = %i[id group_id namespace_id project_id username repository_path].freeze

    # Git over HTTP is the last routable resource still cloned.
    # https://gitlab.com/gitlab-org/gitlab/-/merge_requests/267152 draws it once
    # and empties this list.
    still_cloned_parts = %i[repository_path].freeze

    it 'has no organization-scoped route that takes a group, project or user path' do
      clones = Rails.application.routes.routes.filter_map do |route|
        controller = route.defaults[:controller]
        next unless route.path.spec.to_s.start_with?('/o/:organization_path')
        next unless controller
        next unless routable_controllers.include?(controller) || controller.start_with?(*routable_prefixes)

        # Git over HTTP is cloned whole, so its own `:id` is an LFS lock, not a path.
        next if route.required_parts.intersect?(still_cloned_parts)

        parts = route.required_parts & routable_parts
        next if parts.empty?

        "#{route.path.spec} -> #{controller}##{route.defaults[:action]} (#{parts.join(', ')})"
      end.uniq

      expect(clones).to be_empty,
        "Routable resources are drawn once, so these must not be cloned under /o/:\n#{clones.join("\n")}"
    end
  end

  # `Gitlab::Current::Organization#from_group_params` reads the organization from
  # `namespace_id`/`group_id` before it falls back to `organization_path`, so a
  # route taking both can resolve an organization the URL does not name.
  describe 'organization-scoped routes do not take a namespace path' do
    # The parameters `from_group_params` reads a namespace path from. A `groups`
    # controller's own `:id` is covered by the routable-resource check above.
    namespace_parts = %i[namespace_id group_id].freeze

    # Looks the project up through `Project.in_organization`, so a URL naming
    # another organization 404s. See `Organizations::ProjectsController#project`.
    scoped_to_organization = ['organizations/projects#edit'].freeze

    # A digits-only segment carries a Namespace ID rather than a path.
    def numeric_segment?(route, part)
      requirement = route.requirements[part]

      requirement.is_a?(Regexp) && requirement.source == '\d+'
    end

    it 'has no route whose prefix and namespace can name different organizations' do
      ambiguous = Rails.application.routes.routes.filter_map do |route|
        controller = route.defaults[:controller]
        next unless route.path.spec.to_s.start_with?('/o/:organization_path')
        next unless controller

        parts = route.required_parts & namespace_parts
        next if parts.empty?
        next if parts.all? { |part| numeric_segment?(route, part) }

        endpoint = "#{controller}##{route.defaults[:action]}"
        next if scoped_to_organization.include?(endpoint)

        "#{route.path.spec} -> #{endpoint} (#{parts.join(', ')})"
      end.uniq

      expect(ambiguous).to be_empty,
        "These routes must scope their lookup to the organization in the URL:\n#{ambiguous.join("\n")}"
    end
  end

  describe '/o' do
    specify "to organizations/organizations#index" do
      expect(get("/o")).to route_to('organizations/organizations#index')
    end

    it 'does not match /o with format-like suffix' do
      expect(get('/o.json')).not_to route_to('organizations/organizations#index')
    end
  end

  describe 'root' do
    specify "to root#index" do
      expect(get("/o/my-org")).to route_to('root#index', organization_path: 'my-org')
    end
  end

  describe 'projects' do
    specify "to #new" do
      expect(get("/o/my-org/projects/new")).to route_to('projects#new', organization_path: 'my-org')
    end

    specify "to #create" do
      expect(post("/o/my-org/projects")).to route_to('projects#create', organization_path: 'my-org')
    end
  end

  # Every route cloned into /o/:organization_path must keep working there for every HTTP method.
  # Unscoped routes are drawn first, so one that claims /o/ paths breaks this:
  # https://gitlab.com/gitlab-org/gitlab/-/work_items/634141
  describe 'parity with unscoped routes' do
    # Values tried for each path segment; the first combination that the unscoped twin
    # route accepts is the sample path for that route.
    existing_paths = %w[gitlab gitlab/gitlabhq]
    segment_samples = ['gitlab', 'gitlabhq', 'gitlab/gitlabhq', 'gitlab/gitlabhq.git', '1', 'abc', 'a' * 64]

    before do
      [Project, Group].each do |model|
        allow(model).to receive(:find_by_full_path) { |path, **| existing_paths.include?(path) }
      end
    end

    def recognize(path, verb)
      Rails.application.routes.recognize_path(path, method: verb)
    rescue ActionController::RoutingError
      nil
    end

    def segment_candidates(route, name, samples)
      requirement = route.requirements[name]
      return samples unless requirement

      source = requirement.is_a?(Regexp) ? requirement.source : requirement
      # Enumerated requirements such as `project|group` need their own alternatives.
      alternatives = source.match?(/\A[\w|]+\z/) ? source.split('|') : []

      (samples + alternatives).select { |sample| sample.match?(/\A(?:#{source})\z/) }
    end

    # The unscoped path that reaches the route's unscoped twin, or nil when no sample does.
    def unscoped_sample(route, verb, samples)
      segments = route.required_parts - [:organization_path]
      candidates = segments.map { |name| segment_candidates(route, name, samples) }
      combinations = candidates.empty? ? [[]] : candidates.first.product(*candidates.drop(1))

      combinations.lazy.filter_map do |values|
        path = route.format(segments.zip(values).to_h.merge(organization_path: 'my-org')).delete_prefix('/o/my-org')
        path = '/' if path.empty?
        params = recognize(path, verb)

        [path, params] if params&.values_at(:controller, :action) == route.defaults.values_at(:controller, :action)
      end.first
    end

    it 'routes each organization-scoped path like its unscoped twin' do
      org_routes = Rails.application.routes.routes.select do |route|
        route.path.spec.to_s.start_with?('/o/:organization_path') && route.defaults[:controller]
      end

      mismatches = org_routes.filter_map do |route|
        verb = route.verb.split('|').first
        path, unscoped_params = unscoped_sample(route, verb, segment_samples)
        next unless path

        scoped_params = recognize("/o/my-org#{path.delete_suffix('/')}", verb)
        next if scoped_params == unscoped_params.merge(organization_path: 'my-org')
        # Org-native pages deliberately replace their cloned twin.
        next if scoped_params&.dig(:controller)&.start_with?('organizations/')

        "#{verb} /o/my-org#{path} -> #{scoped_params&.values_at(:controller, :action)&.join('#')}"
      end

      expect(mismatches).to be_empty, "Routes that behave differently under /o/:\n#{mismatches.join("\n")}"
    end
  end

  describe 'groups' do
    specify "to #new" do
      expect(get("/o/my-org/groups/new")).to route_to('groups#new', organization_path: 'my-org')
    end

    specify "to #create" do
      expect(post("/o/my-org/groups")).to route_to('groups#create', organization_path: 'my-org')
    end
  end

  describe 'project dashboards' do
    specify "to #index" do
      expect(get("/o/my-org/dashboard/projects")).to route_to("dashboard/projects#index", organization_path: 'my-org')
    end

    %w[
      contributed
      starred
      personal
      member
      inactive
    ].each do |action|
      specify "to #{action}" do
        expect(get("/o/my-org/dashboard/projects/#{action}")).to route_to("dashboard/projects#index",
          organization_path: 'my-org')
      end
    end
  end

  describe 'groups dashboards' do
    specify "to #index" do
      expect(get("/o/my-org/dashboard/groups")).to route_to("dashboard/groups#index", organization_path: 'my-org')
    end

    %w[
      member
      inactive
    ].each do |action|
      specify "to #{action}" do
        expect(get("/o/my-org/dashboard/groups/#{action}")).to route_to("dashboard/groups#index",
          organization_path: 'my-org')
      end
    end
  end
end
