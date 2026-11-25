# frozen_string_literal: true

module Repositories
  class ApplicationController < ::ApplicationController
    skip_before_action :authenticate_user!

    # These controllers answer Workhorse with JSON or plain text, but Git's
    # `Accept: */*` resolves to HTML, which would build `gon` for a page that
    # is never rendered. The callback's own `if: :html_request?` runs first.
    skip_before_action :add_gon_variables, if: -> {
      Feature.enabled?(:git_http_skip_gon_variables, Feature.current_request)
    }

    # LFS enforces maintenance mode itself after the access checks (see
    # LfsRequest#check_organization_maintenance_mode!), so it responds with the
    # LFS content type and does not disclose the maintenance status to users
    # without access. The generic hook would run before those checks.
    skip_before_action :enforce_organization_maintenance_mode
  end
end
