# frozen_string_literal: true

RSpec.shared_context 'with a project and group that share a numeric id' do
  # The shared integration endpoints resolve both a project and a group from
  # params[:id], so a token scoped to one must not satisfy the other.
  let_it_be(:same_id_group) { create(:group, owners: user) }
  let_it_be(:same_id_project) do
    create(:project, id: same_id_group.id, creator_id: user.id, namespace: user.namespace, owners: [user])
  end

  let(:same_id) { same_id_group.id }

  def granular_token_for(boundary_object, permission)
    assignable = ::Authz::PermissionGroups::Assignable.for_permission(permission).first

    create(:granular_pat, user: user, boundary: ::Authz::Boundary.for(boundary_object),
      permissions: [assignable.name])
  end
end
