# frozen_string_literal: true

# rubocop:disable Mcp/UseApiService -- does not depend directly on REST API
module Mcp
  module Tools
    module Base
      class GraphqlService < BaseService
        include Mcp::Tools::Concerns::Versionable
        include Mcp::Tools::Concerns::GranularTokenAuthorization
        extend Gitlab::Utils::Override

        def initialize(name:, version: nil)
          super(name: name)
          initialize_version(version)
        end

        override :set_cred
        def set_cred(current_user: nil, access_token: nil)
          @current_user = current_user
          @access_token = access_token
        end

        override :governed_containers
        def governed_containers(arguments)
          tool = build_graphql_tool(reject_omitted_arguments(arguments))
          return super unless tool.respond_to?(:governed_containers)

          tool_governed_containers(arguments) { tool.governed_containers }
        end

        override :execute
        def execute(request: nil, params: nil)
          unless current_user.present?
            return Response.error("#{self.class.name}: current_user is not set", reason: Response::Reason::UNAUTHORIZED)
          end

          super
        end

        protected

        # Subclasses should override this to return their GraphQL tool class
        def graphql_tool_class
          raise NotImplementedError, "#{self.class.name}#graphql_tool_class must be implemented"
        end

        # Default implementation - can be overridden in subclasses
        def perform_default(_arguments = {})
          raise NoMethodError, "No implementation found for version #{version}"
        end

        private

        def execute_graphql_tool(arguments)
          build_graphql_tool(arguments).execute
        end

        def build_graphql_tool(arguments)
          graphql_tool_class.new(
            current_user: current_user,
            params: arguments,
            version: version,
            access_token: access_token,
            request: request
          )
        end
      end
    end
  end
end
# rubocop:enable Mcp/UseApiService
