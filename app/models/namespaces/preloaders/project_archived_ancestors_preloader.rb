# frozen_string_literal: true

module Namespaces
  module Preloaders
    # Preloads the associations that Project#self_or_ancestors_archived? reads, so iterating a
    # collection answers the check from memory instead of firing a query per project.
    class ProjectArchivedAncestorsPreloader
      def initialize(projects)
        @projects = projects
      end

      # Returns the projects as a loaded array, which callers iterating the same collection should use.
      def execute
        projects = @projects.to_a

        ActiveRecord::Associations::Preloader.new(
          records: projects,
          associations: [
            :project_namespace,
            { namespace: [:namespace_settings, :namespace_settings_with_ancestors_inherited_settings] }
          ]
        ).call

        projects
      end
    end
  end
end
