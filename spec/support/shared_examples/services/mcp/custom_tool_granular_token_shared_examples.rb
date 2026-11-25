# frozen_string_literal: true

# Requires `service`, `tool_params`, `current_user` and `boundary_resource`.
# `allow_public_access` is what the tool passes for this target: tools read as the
# token's user, so only a tool whose result is the same for every reader passes true.
RSpec.shared_examples 'an MCP custom tool authorizing granular tokens' do |permission, allow_public_access: false|
  let(:token) { create(:granular_pat, user: current_user) }

  it "checks #{permission} on the target's boundary" do
    authorize_service = instance_double(
      ::Authz::Tokens::AuthorizeGranularScopesService, execute: ServiceResponse.success
    )

    expect(::Authz::Tokens::AuthorizeGranularScopesService).to receive(:new).with(
      boundaries: an_object_having_attributes(boundary: boundary_resource),
      permissions: [permission],
      token: token,
      allow_public_access: allow_public_access
    ).and_return(authorize_service)

    service.set_cred(current_user: current_user, access_token: token)
    service.execute(request: nil, params: tool_params)
  end

  it "declares #{permission} for the target's boundary type" do
    boundary_types = ::Authz::PermissionGroups::Assignable.for_permission(permission).flat_map(&:boundaries)

    expect(boundary_types.map(&:to_s)).to include(::Authz::Boundary.for(boundary_resource).type_label)
  end
end
