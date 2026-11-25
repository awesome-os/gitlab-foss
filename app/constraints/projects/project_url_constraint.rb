# frozen_string_literal: true

module Projects
  class ProjectUrlConstraint
    def matches?(request, existence_check: true)
      namespace_path = request.params[:namespace_id]
      project_path = request.params[:project_id] || request.params[:id]
      full_path = [namespace_path, project_path].join('/')

      return false unless ProjectPathValidator.valid_path?(full_path)
      return true unless existence_check

      follow_redirects = request.get?
      project = Project.find_by_full_path(full_path, follow_redirects: follow_redirects)
      return false unless project

      # The controller needs the same record; hand it over so it does not look it up again.
      Gitlab::Routing::ConstraintLookup.store(request, Project, full_path, follow_redirects, project)

      true
    end
  end
end
