# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Every API endpoint', feature_category: :scalability do
  context 'feature categories' do
    let_it_be(:feature_categories) do
      Gitlab::FeatureCategories.default.categories.map(&:to_sym).to_set
    end

    let_it_be(:api_endpoints) do
      Gitlab::RequestEndpoints.all_api_endpoints.map do |route|
        klass = route.app.options[:for]

        [klass, API::Base.path_for_app(route.app), klass.try(:feature_category_for_app, route.app)]
      end
    end

    let_it_be(:routes_without_category) do
      api_endpoints.map do |(klass, path, category)|
        next if category

        "#{klass}##{path}"
      end.compact.uniq
    end

    it "has feature categories" do
      expect(routes_without_category).to be_empty, "#{routes_without_category} did not have a category"
    end

    it "recognizes the feature categories" do
      routes_unknown_category = api_endpoints.map do |(klass, path, used_category)|
        next unless used_category
        next if used_category == :not_owned

        [klass, path, used_category] unless feature_categories.include?(used_category)
      end.compact

      message = -> do
        list = routes_unknown_category.map do |klass, path, category|
          "- #{klass} (#{path}): #{category}"
        end

        <<~MESSAGE
          Unknown categories found for:
          #{list.join("\n")}
        MESSAGE
      end

      expect(routes_unknown_category).to be_empty, message
    end

    # This is required for API::Base.path_for_app to work, as it picks
    # the first path
    it "has no routes with multiple paths" do
      routes_with_multiple_paths = API::API.routes.select { |route| route.app.options[:path].length != 1 }
      failure_routes = routes_with_multiple_paths.map { |route| "#{route.app.options[:for]}:[#{route.app.options[:path].join(', ')}]" }

      expect(routes_with_multiple_paths).to be_empty, "#{failure_routes} have multiple paths"
    end

    context 'with feature categories or urgencies set for specific paths' do
      let_it_be(:paths_without_route_by_class) do
        api_endpoints.group_by(&:first).to_h do |klass, paths|
          [klass.name, paths_without_route(klass, paths.map(&:second))]
        end
      end

      it "doesn't define feature categories or urgencies on removed actions", :aggregate_failures do
        paths_without_route_by_class.each do |klass_name, paths|
          expect(paths).to be_empty,
            "#{klass_name} sets a feature category or urgency for #{paths}, but the route does not exist"
        end
      end

      it 'reports a path that has no route' do
        klass = Class.new do
          include Gitlab::EndpointAttributes

          feature_category :team_planning, %w[/existing /removed]
        end

        expect(paths_without_route(klass, %w[/existing])).to contain_exactly('/removed')
      end
    end
  end

  # On Grape 3.x a route-level `format:` stops constraining the implicit `(.:format)` suffix,
  # so any extension matches. See ::API::JSON_FORMAT_SUFFIX_REQUIREMENT.
  context 'format suffixes' do
    # Mustermann compiles an unconstrained suffix to its default segment capture.
    let(:unconstrained_capture) { '(?<format>[^' }

    let(:routes_not_enforcing_their_format) do
      API::API.routes.select do |route|
        route.options[:format].present? &&
          route.pattern.to_regexp.source.include?(unconstrained_capture)
      end
    end

    # The guard below cannot fail on 2.4, so pin the sentinel against real Mustermann output:
    # if its rendering ever changes, this fails instead of the guard silently matching nothing.
    it 'matches how Mustermann renders an unconstrained suffix' do
      pattern = Mustermann.new('/x(.:format)', type: :grape)

      expect(pattern.to_regexp.source).to include(unconstrained_capture)
    end

    it 'constrains the URL suffix on every route that declares a format' do
      message = -> do
        list = routes_not_enforcing_their_format.map do |route|
          "- #{route.options[:for]} #{route.request_method} #{route.origin} (format: #{route.options[:format]})"
        end

        <<~MESSAGE
          These routes declare a format but accept any URL suffix, so an unknown extension
          returns the endpoint's body instead of a 404. Add a matching `requirements` to each
          (see ::API::JSON_FORMAT_SUFFIX_REQUIREMENT):
          #{list.join("\n")}
        MESSAGE
      end

      expect(routes_not_enforcing_their_format).to be_empty, message
    end
  end

  def paths_without_route(klass, existing_paths)
    defined_paths = klass.send(:class_attributes)[:endpoint_attributes_config]&.defined_actions || []

    defined_paths - existing_paths
  end
end
