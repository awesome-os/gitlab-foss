# frozen_string_literal: true

module API
  class Base < Grape::API::Instance # rubocop:disable API/Base
    include ::Gitlab::EndpointAttributes

    class << self
      def feature_category_for_app(app)
        path = path_for_app(app)
        route_level_attributes&.attribute_for_action(path, :feature_category) || feature_category_for_action(path)
      end

      def urgency_for_app(app)
        path = path_for_app(app)
        route_level_attributes&.attribute_for_action(path, :urgency) || urgency_for_action(path)
      end

      def path_for_app(app)
        normalize_path(app.namespace, app.options[:path].first)
      end

      def endpoint_id_for_route(route)
        # Grape's generated OPTIONS and 405 handlers carry no request method, which would
        # interpolate to " /api/:version/users". Return nil instead
        return if route.is_a?(Grape::Router::GreedyRoute)

        "#{route.request_method} #{route.origin}"
      end

      # Opt out of the global Current.organization assignment performed in
      # API::API's before_validation hook. Use this on classes whose endpoints
      # set Current.organization from non-user request state (for example the
      # runner's own organization) inside the endpoint body, where Grape's
      # filter ordering would otherwise let the global fallback win.
      def skip_global_organization_setup!
        @skip_global_organization_setup = true
      end

      def skip_global_organization_setup?
        @skip_global_organization_setup == true
      end

      # @note Stored on the route because the namespace here excludes any prefix the class is mounted under.
      def route(methods, paths = ['/'], route_options = {}, &block)
        attributes = route_options.extract!(:feature_category, :urgency).compact
        if attributes[:urgency] && !::Gitlab::EndpointAttributes::Config::REQUEST_URGENCIES.key?(attributes[:urgency])
          raise ArgumentError, "Urgency not supported: #{attributes[:urgency]}"
        end

        route_setting(:endpoint_attributes, attributes) if attributes.any?

        super
      end

      # @note Each mount adds a prefix to the paths, so it rebuilds the tables of the mounted classes.
      def mount(mounts, *opts)
        super

        (mounts.respond_to?(:each_pair) ? mounts.keys : [mounts]).each { |app| app.try(:build_route_level_attributes) }
      end

      # @note Also rebuilds the classes mounted inside this one, since their full paths changed too.
      def build_route_level_attributes
        config = ::Gitlab::EndpointAttributes::Config.new
        endpoints.each do |endpoint|
          if endpoint.options[:app]
            endpoint.options[:app].try(:build_route_level_attributes)
            next
          end

          attributes = endpoint.route_setting(:endpoint_attributes)
          config.set([path_for_app(endpoint)], attributes) if attributes
        end
        @route_level_attributes = config.defined_actions.any? ? config : nil
      end

      private

      # @note Classes that are never mounted, such as API::API, build their table on first use.
      def route_level_attributes
        return @route_level_attributes if defined?(@route_level_attributes)

        build_route_level_attributes
      end

      def normalize_path(namespace, path)
        [namespace.presence, path.to_s.chomp('/').presence].compact.join('/')
      end
    end
  end
end
