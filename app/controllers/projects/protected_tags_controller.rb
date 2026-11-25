# frozen_string_literal: true

class Projects::ProtectedTagsController < Projects::ProtectedRefsController
  # rubocop:disable Rails/LexicallyScopedActionFilter -- actions are defined in Projects::ProtectedRefsController
  before_action :authorize_create_protected_tag!, only: :create
  before_action :authorize_update_protected_tag!, only: [:index, :show, :update]
  before_action :authorize_delete_protected_tag!, only: :destroy
  # rubocop:enable Rails/LexicallyScopedActionFilter

  protected

  def ref_type
    :tags
  end

  def project_refs
    @project.repository.tags
  end

  def service_namespace
    ::ProtectedTags
  end

  def find_protected_ref
    @project.protected_tags.find(params.permit(:id)[:id])
  end

  def access_levels
    [:create_access_levels]
  end

  def protected_ref_params
    params.require(:protected_tag).permit(:name, create_access_levels_attributes: access_level_attributes)
  end

  def authorize_create_protected_tag!
    access_denied! unless can?(current_user, :create_protected_tag, project)
  end

  def authorize_update_protected_tag!
    access_denied! unless can?(current_user, :update_protected_tag, project)
  end

  def authorize_delete_protected_tag!
    access_denied! unless can?(current_user, :delete_protected_tag, project)
  end
end
