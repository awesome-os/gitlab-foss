# frozen_string_literal: true

module ProtectedTags
  class UpdateService < ::BaseService
    def execute(protected_tag)
      raise Gitlab::Access::AccessDeniedError unless can?(current_user, :update_protected_tag, project)

      protected_tag.update(params)
      protected_tag
    end
  end
end
