# frozen_string_literal: true

match '/api/graphql', via: [:get, :post], to: 'graphql#execute'
match '/api/glql', via: [:get, :post], to: 'glql/base#execute'
get '/-/graphql-explorer', to: API::Graphql::GraphqlExplorerController.action(:show)

::API::API.logger Rails.logger

# The mount is unanchored and drawn before the web routes, so without a constraint every web
# request is dispatched into Grape and scanned against all of its routes before cascading back.
# `/+` mirrors Grape::Router.normalize_path squeezing slashes; an `/api/` path skips the flag.
api_mount_constraint = ->(request) do
  request.path_info.match?(%r{\A/+api/}) ||
    Feature.disabled?(:api_mount_only_for_api_paths, Feature.current_request)
end

mount ::API::API => '/', constraints: api_mount_constraint
