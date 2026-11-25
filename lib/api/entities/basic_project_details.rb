# frozen_string_literal: true

module API
  module Entities
    class BasicProjectDetails < Entities::ProjectIdentity
      extend ::API::ProjectsRelationBuilder
      include Gitlab::Utils::StrongMemoize

      expose :default_branch_or_main, documentation: { type: 'String', example: 'main', desc: 'Default branch of the project.' }, as: :default_branch, if: ->(project, options) { Ability.allowed?(options[:current_user], :read_code, project) }
      # Avoids an N+1 query: https://github.com/mbleigh/acts-as-taggable-on/issues/91#issuecomment-168273770

      expose :topic_names, as: :tag_list, documentation: { type: 'String', is_array: true, example: ['tag'], desc: 'Deprecated. Use `topics` instead. List of tags for the project.' }
      expose :topic_names, as: :topics, documentation: { type: 'String', is_array: true, example: ['topic'], desc: 'List of topics for the project.' }

      expose :ssh_url_to_repo, documentation: { type: 'String', example: 'git@gitlab.example.com:gitlab/gitlab.git', desc: 'SSH URL to clone the repository.' }
      expose :http_url_to_repo, documentation: { type: 'String', example: 'https://gitlab.example.com/gitlab/gitlab.git', desc: 'HTTP URL to clone the repository.' }
      expose :web_url, documentation: { type: 'String', example: 'https://gitlab.example.com/gitlab/gitlab', desc: 'URL to access the project in a browser.' }
      with_options if: ->(_, _) { user_has_access_to_project_repository? } do
        expose :readme_url, documentation: { type: 'String', example: 'https://gitlab.example.com/gitlab/gitlab/blob/master/README.md', desc: "URL to the project's README file. Returned only if the user can read the repository." }
        expose :forks_count, documentation: { type: 'Integer', example: 1, desc: 'Number of forks of the project. Returned only if the user can read the repository.' }
      end

      expose :license_url, if: :license, documentation: { type: 'String', example: 'https://gitlab.example.com/gitlab/gitlab/blob/master/LICENCE', desc: "URL to the project's license file. Returned only when getting a single project with `license=true`." } do |project|
        license = project.repository.license_blob

        if license
          Gitlab::Routing.url_helpers.project_blob_url(project, File.join(project.default_branch, license.path))
        end
      end

      expose :license, using: ::API::Entities::LicenseBasic, if: :license do |project|
        project.repository.license
      end

      expose :avatar_url, documentation: { type: 'String', example: 'http://example.com/uploads/project/avatar/3/uploads/avatar.png', desc: "URL to the project's avatar image." } do |project, options|
        project.avatar_url(only_path: false)
      end

      expose :star_count, documentation: { type: 'Integer', example: 1, desc: 'Number of stars the project has received.' }
      expose :last_activity_at, documentation: {
        type: 'DateTime',
        example: '2013-09-30T13:46:02Z',
        desc: 'Timestamp of the last activity in the project. Updates at most once per hour, ' \
          'so it can be up to one hour out of date.'
      }
      expose :visibility, documentation: {
        type: 'String',
        example: 'public',
        desc: 'Visibility level of the project. Possible values: `private`, `internal`, or `public`.'
      }
      expose :namespace, using: ::API::Entities::NamespaceBasic,
        documentation: { type: 'API::Entities::NamespaceBasic', desc: 'Namespace information for the project.' }
      expose :custom_attributes, using: ::API::Entities::CustomAttribute, if: :with_custom_attributes,
        documentation: { is_array: true }

      expose :repository_storage, documentation: { type: 'String', example: 'default', desc: "Storage location for the project's repository. Returned only for administrators." }, if: ->(project, options) {
        Ability.allowed?(options[:current_user], :change_repository_storage, project)
      }

      # rubocop: disable CodeReuse/ActiveRecord
      def self.preload_relation(projects_relation, options = {})
        # Preloading topics, should be done with using only `:topics`,
        # as `:topics` are defined as: `has_many :topics, through: :project_topics`
        # N+1 is solved then by using `subject.topics.map(&:name)`
        # MR describing the solution: https://gitlab.com/gitlab-org/gitlab-foss/merge_requests/20555
        projects_relation.preload(:project_feature, :route, :project_namespace, :organization)
                         .preload(:import_state, :topics)
                         .preload(:auto_devops)
                         .preload(namespace: [:route, :owner, :namespace_settings_with_ancestors_inherited_settings])
      end
      # rubocop: enable CodeReuse/ActiveRecord

      def self.execute_batch_counting(projects_relation)
        # Call the count methods on every project, so the BatchLoader would load them all at
        # once when the entities are rendered
        projects_relation.each(&:forks_count)

        super
      end

      def self.postload_relation(projects_relation, options = {}) end

      private

      alias_method :project, :object

      def topic_names
        # Topics is a preloaded association. If we perform then sorting
        # through the database, it will trigger a new query, ending up
        # in an N+1 if we have several projects
        strong_memoize(:topic_names) do
          project.topics.pluck(:name).sort # rubocop:disable CodeReuse/ActiveRecord
        end
      end

      def user_has_access_to_project_repository?
        Ability.allowed?(options[:current_user], :read_code, project)
      end
    end
  end
end
