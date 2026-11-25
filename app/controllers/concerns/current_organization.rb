# frozen_string_literal: true

module CurrentOrganization
  extend ActiveSupport::Concern

  def set_current_organization
    # Resolved unconditionally, even if #organization is already assigned
    # elsewhere, so ::Current.organization_resolver is always usable below.
    ::Current.organization_resolver ||= Gitlab::Current::Organization.new(
      params: organization_params,
      user: current_user,
      rack_env: request.env
    )

    return if ::Current.organization_assigned

    ::Current.organization = ::Current.organization_resolver.organization
  end
end
