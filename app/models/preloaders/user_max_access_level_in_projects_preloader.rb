# frozen_string_literal: true

module Preloaders
  # This class preloads the max access level (role) for the user within the given projects and
  # stores the values in requests store via the ProjectTeam class.
  class UserMaxAccessLevelInProjectsPreloader
    def initialize(projects, user)
      # Arrays are passed as given, so projects and IDs already cached for the request are reused.
      # Push a relation's base query in to a sub-select to avoid table name clashes.
      @projects = projects.is_a?(Array) ? projects : Project.id_in(projects.subquery(:id))

      @user = user
    end

    def execute
      return unless @user

      Gitlab::Instrumentation::Authz.measure do
        levels = Authz::UserProjectGrants.new(@user.id).max_access_levels(@projects)

        # The request cache key only needs the project's class and ID, so the full record isn't loaded.
        levels.each do |project_id, access_level|
          ProjectTeam.new(Project.instantiate('id' => project_id))
            .write_member_access_for_user_id(@user.id, access_level)
        end
      end
    end
  end
end
