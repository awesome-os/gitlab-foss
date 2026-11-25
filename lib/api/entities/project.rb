# frozen_string_literal: true

module API
  module Entities
    class Project < ProjectDetails
      include ::API::Helpers::RelatedResourcesHelpers

      expose :container_registry_url, as: :container_registry_image_prefix, documentation: { type: 'String', example: 'registry.gitlab.example.com/gitlab/gitlab-client', desc: 'Prefix for container registry images. Returned only if the container registry is enabled for the instance.' }, if: ->(_, _) { Gitlab.config.registry.enabled }

      expose :_links, documentation: { type: 'Hash', desc: 'Links to API endpoints related to the project.' } do
        expose :self, documentation: { type: 'String', example: 'https://gitlab.example.com/api/v4/projects/4', desc: 'URL to the project resource.' } do |project|
          expose_url(api_v4_projects_path(id: project.id))
        end

        expose :issues, documentation: { type: 'String', example: 'https://gitlab.example.com/api/v4/projects/4/issues', desc: "URL to the project's issues. Returned only if issues are available to the user." }, if: ->(project, options) { issues_available?(project, options) } do |project|
          expose_url(api_v4_projects_issues_path(id: project.id))
        end

        expose :merge_requests, documentation: { type: 'String', example: 'https://gitlab.example.com/api/v4/projects/4/merge_requests', desc: "URL to the project's merge requests. Returned only if merge requests are available to the user." }, if: ->(project, options) { mrs_available?(project, options) } do |project|
          expose_url(api_v4_projects_merge_requests_path(id: project.id))
        end

        expose :repo_branches, documentation: { type: 'String', example: 'https://gitlab.example.com/api/v4/projects/4/repository/branches', desc: "URL to the project's repository branches." } do |project|
          expose_url(api_v4_projects_repository_branches_path(id: project.id))
        end

        expose :labels, documentation: { type: 'String', example: 'https://gitlab.example.com/api/v4/projects/4/labels', desc: "URL to the project's labels." } do |project|
          expose_url(api_v4_projects_labels_path(id: project.id))
        end

        expose :events, documentation: { type: 'String', example: 'https://gitlab.example.com/api/v4/projects/4/events', desc: "URL to the project's events." } do |project|
          expose_url(api_v4_projects_events_path(id: project.id))
        end

        expose :members, documentation: { type: 'String', example: 'https://gitlab.example.com/api/v4/projects/4/members', desc: "URL to the project's members." } do |project|
          expose_url(api_v4_projects_members_path(id: project.id))
        end

        expose :cluster_agents, documentation: { type: 'String', example: 'https://gitlab.example.com/api/v4/projects/4/cluster_agents', desc: "URL to the project's cluster agents." } do |project|
          expose_url(api_v4_projects_cluster_agents_path(id: project.id))
        end
      end

      expose :marked_for_deletion_at, documentation: { type: 'DateTime', example: '2020-05-07T04:27:17.016Z', desc: 'Deprecated. Use `marked_for_deletion_on` instead. Date when the project is scheduled for deletion.' }
      expose :marked_for_deletion_at, as: :marked_for_deletion_on, documentation: { type: 'DateTime', example: '2020-05-07T04:27:17.016Z', desc: 'Date when the project is scheduled for deletion.' }

      expose :packages_enabled, documentation: { type: 'Boolean', desc: '[Deprecated](https://gitlab.com/gitlab-org/gitlab/-/work_items/454759) in GitLab 17.10. Use `package_registry_access_level` instead. If `true`, the package registry is enabled for the project.' }
      expose :empty_repo?, as: :empty_repo, documentation: { type: 'Boolean', desc: 'If `true`, the repository is empty.' }
      expose :self_or_ancestors_archived?, as: :archived, documentation: { type: 'Boolean', desc: 'If `true`, the project or one of its ancestor groups is archived.' }
      expose :owner, using: ::API::Entities::UserBasic, unless: ->(project, options) { project.group },
        documentation: { type: 'API::Entities::UserBasic', desc: 'Owner of the project. Returned only for projects in a personal namespace.' }
      expose :resolve_outdated_diff_discussions, documentation: { type: 'Boolean', desc: 'If `true`, outdated diff discussions are automatically resolved.' }
      expose :container_expiration_policy,
        using: ::API::Entities::ContainerExpirationPolicy,
        documentation: { type: 'API::Entities::ContainerExpirationPolicy', desc: 'Settings for the container image expiration policy.' },
        if: ->(project, _) { project.container_expiration_policy }
      expose :repository_object_format, documentation: { type: 'String', example: 'sha1', desc: 'Object format used by the repository. Possible values: `sha1` or `sha256`.' }

      # Expose old field names with the new permissions methods to keep API compatible
      # TODO: remove in API v5, replaced by *_access_level
      expose(:issues_enabled, documentation: { type: 'Boolean', desc: 'Deprecated. Use `issues_access_level` instead. If `true`, issues are enabled for the project.' }) { |project, options| project.feature_available?(:issues, options[:current_user]) }
      expose(:merge_requests_enabled, documentation: { type: 'Boolean', desc: 'Deprecated. Use `merge_requests_access_level` instead. If `true`, merge requests are enabled for the project.' }) { |project, options| project.feature_available?(:merge_requests, options[:current_user]) }
      expose(:wiki_enabled, documentation: { type: 'Boolean', desc: 'Deprecated. Use `wiki_access_level` instead. If `true`, the wiki is enabled for the project.' }) { |project, options| project.feature_available?(:wiki, options[:current_user]) }
      expose(:jobs_enabled, documentation: { type: 'Boolean', desc: 'Deprecated. Use `builds_access_level` instead. If `true`, jobs are enabled for the project.' }) { |project, options| project.feature_available?(:builds, options[:current_user]) }
      expose(:snippets_enabled, documentation: { type: 'Boolean', desc: 'Deprecated. Use `snippets_access_level` instead. If `true`, snippets are enabled for the project.' }) { |project, options| project.feature_available?(:snippets, options[:current_user]) }
      expose(:container_registry_enabled, documentation: { type: 'Boolean', desc: 'Deprecated. Use `container_registry_access_level` instead. If `true`, the container registry is enabled for the project.' }) { |project, options| project.feature_available?(:container_registry, options[:current_user]) }
      expose(:service_desk_enabled, documentation: { type: 'Boolean', desc: 'If `true`, Service Desk is enabled for the project. It is `true` only when the project setting is on and incoming email with a wildcard address is configured for the instance.' }) { |project, options| ::ServiceDesk.enabled?(project) }

      expose :service_desk_address, documentation: { type: 'String', example: 'address@example.com', desc: 'Email address for the Service Desk. Returned only for users with at least the Planner role.' },
        if: ->(project, options) { Ability.allowed?(options[:current_user], :admin_issue, project) } do |project|
        ::ServiceDesk::Emails.new(project).address
      end

      expose(:can_create_merge_request_in, documentation: { type: 'Boolean', desc: 'If `true`, the current user can create merge requests in the project.' }) do |project, options|
        Ability.allowed?(options[:current_user], :create_merge_request_in, project)
      end

      expose(:issues_access_level, documentation: { type: 'String', example: 'enabled', desc: 'Access level for the issues feature. Possible values: `disabled`, `private`, or `enabled`.' }) { |project, options| project_feature_string_access_level(project, :issues) }
      expose(:repository_access_level, documentation: { type: 'String', example: 'enabled', desc: 'Access level for the repository feature. Possible values: `disabled`, `private`, or `enabled`.' }) { |project, options| project_feature_string_access_level(project, :repository) }
      expose(:merge_requests_access_level, documentation: { type: 'String', example: 'enabled', desc: 'Access level for the merge requests feature. Possible values: `disabled`, `private`, or `enabled`.' }) { |project, options| project_feature_string_access_level(project, :merge_requests) }
      expose(:forking_access_level, documentation: { type: 'String', example: 'enabled', desc: 'Access level for forking the project. Possible values: `disabled`, `private`, or `enabled`.' }) { |project, options| project_feature_string_access_level(project, :forking) }
      expose(:wiki_access_level, documentation: { type: 'String', example: 'enabled', desc: 'Access level for the wiki feature. Possible values: `disabled`, `private`, or `enabled`.' }) { |project, options| project_feature_string_access_level(project, :wiki) }
      expose(:builds_access_level, documentation: { type: 'String', example: 'enabled', desc: 'Access level for the CI/CD builds feature. Possible values: `disabled`, `private`, or `enabled`.' }) { |project, options| project_feature_string_access_level(project, :builds) }
      expose(:snippets_access_level, documentation: { type: 'String', example: 'enabled', desc: 'Access level for the snippets feature. Possible values: `disabled`, `private`, or `enabled`.' }) { |project, options| project_feature_string_access_level(project, :snippets) }
      expose(:pages_access_level, documentation: { type: 'String', example: 'enabled', desc: 'Access level for GitLab Pages. Possible values: `disabled`, `private`, `enabled`, or `public`.' }) { |project, options| project_feature_string_access_level(project, :pages) }
      expose(:analytics_access_level, documentation: { type: 'String', example: 'enabled', desc: 'Access level for analytics features. Possible values: `disabled`, `private`, or `enabled`.' }) { |project, options| project_feature_string_access_level(project, :analytics) }
      expose(:container_registry_access_level, documentation: { type: 'String', example: 'enabled', desc: 'Access level for the container registry. Possible values: `disabled`, `private`, or `enabled`.' }) { |project, options| project_feature_string_access_level(project, :container_registry) }
      expose(:security_and_compliance_access_level, documentation: { type: 'String', example: 'enabled', desc: 'Access level for security and compliance features. Possible values: `disabled`, `private`, or `enabled`.' }) { |project, options| project_feature_string_access_level(project, :security_and_compliance) }
      expose(:releases_access_level, documentation: { type: 'String', example: 'enabled', desc: 'Access level for the releases feature. Possible values: `disabled`, `private`, or `enabled`.' }) { |project, options| project_feature_string_access_level(project, :releases) }
      expose(:environments_access_level, documentation: { type: 'String', example: 'enabled', desc: 'Access level for the environments feature. Possible values: `disabled`, `private`, or `enabled`.' }) { |project, options| project_feature_string_access_level(project, :environments) }
      expose(:feature_flags_access_level, documentation: { type: 'String', example: 'enabled', desc: 'Access level for the feature flags feature. Possible values: `disabled`, `private`, or `enabled`.' }) { |project, options| project_feature_string_access_level(project, :feature_flags) }
      expose(:infrastructure_access_level, documentation: { type: 'String', example: 'enabled', desc: 'Access level for the infrastructure feature. Possible values: `disabled`, `private`, or `enabled`.' }) { |project, options| project_feature_string_access_level(project, :infrastructure) }
      expose(:monitor_access_level, documentation: { type: 'String', example: 'enabled', desc: 'Access level for the monitor feature. Possible values: `disabled`, `private`, or `enabled`.' }) { |project, options| project_feature_string_access_level(project, :monitor) }
      expose(:model_experiments_access_level, documentation: { type: 'String', example: 'enabled', desc: 'Access level for the model experiments feature. Possible values: `disabled`, `private`, or `enabled`.' }) { |project, options| project_feature_string_access_level(project, :model_experiments) }
      expose(:model_registry_access_level, documentation: { type: 'String', example: 'enabled', desc: 'Access level for the model registry feature. Possible values: `disabled`, `private`, or `enabled`.' }) { |project, options| project_feature_string_access_level(project, :model_registry) }
      expose(:package_registry_access_level, documentation: { type: 'String', example: 'enabled', desc: 'Access level for the package registry feature. Possible values: `disabled`, `private`, `enabled`, or `public`.' }) { |project, options| project_feature_string_access_level(project, :package_registry) }

      expose(:emails_disabled, documentation: { type: 'Boolean', desc: 'Deprecated. Use `emails_enabled` instead. If `true`, emails are disabled for the project.' }) { |project, options| project.emails_disabled? }
      expose :emails_enabled, documentation: { type: 'Boolean', desc: 'If `true`, emails are enabled for the project.' }
      expose(:show_diff_preview_in_email, documentation: { type: 'Boolean', desc: 'If `true`, diff previews are shown in email notifications.' }) { |project, options| project.show_diff_preview_in_email? }

      expose :shared_runners_enabled, documentation: { type: 'Boolean', desc: 'If `true`, shared runners are enabled for the project.' }
      expose :lfs_enabled?, as: :lfs_enabled, documentation: { type: 'Boolean', desc: 'If `true`, Git LFS is enabled for the project.' }
      expose :creator_id, documentation: { type: 'Integer', format: 'int64', example: 1, desc: 'ID of the user who created the project.' }
      expose :mr_default_target_self, if: ->(project) { project.forked? }, documentation: { type: 'Boolean', desc: 'If `true`, merge requests target this project by default. If `false`, merge requests target the upstream project. Returned only if the project is a fork.' }

      expose :import_url, documentation: { type: 'String', example: 'https://gitlab.com/gitlab/gitlab.git', desc: 'URL the project was imported from. Returned only for users with at least the Maintainer role.' }, if: ->(project, options) { Ability.allowed?(options[:current_user], :admin_project, project) } do |project|
        project[:import_url]
      end
      expose :import_type, documentation: { type: 'String', example: 'git', desc: 'Type of import used for the project. Returned only for users with at least the Maintainer role.' }, if: ->(project, options) { Ability.allowed?(options[:current_user], :admin_project, project) }
      expose :import_status, documentation: { type: 'String', example: 'none', desc: 'Status of the project import.' }
      expose :import_error, documentation: { type: 'String', example: 'Import error', desc: 'Error message if the import failed. Returned only for users with at least the Maintainer role, and only when creating, updating, forking, or getting a single project.' }, if: ->(_project, options) { options[:user_can_admin_project] } do |project|
        project.import_state&.last_error
      end
      expose :open_issues_count, documentation: { type: 'Integer', example: 1, desc: 'Number of open issues. Returned only if issues are available to the user.' }, if: ->(project, options) { project.feature_available?(:issues, options[:current_user]) }
      expose :description_html, documentation: { type: 'String', desc: 'Description of the project, rendered as HTML.' } do |project|
        MarkupHelper.markdown_field(project, :description, current_user: options[:current_user])
      end
      expose :updated_at, documentation: { type: 'DateTime', example: '2020-05-07T04:27:17.016Z', desc: 'Timestamp when the project was last updated.' }

      with_options if: ->(_, _) { Ability.allowed?(options[:current_user], :admin_project, project) } do
        # CI/CD Settings
        expose :ci_default_git_depth, documentation: { type: 'Integer', example: 20, desc: 'Default Git depth for CI/CD pipelines. Returned only for users with at least the Maintainer role.' }
        expose :ci_delete_pipelines_in_seconds, documentation: { type: 'Integer', example: 86400, desc: 'Time in seconds before old pipelines are deleted. Returned only for users with at least the Maintainer role.' }
        expose :ci_forward_deployment_enabled, documentation: { type: 'Boolean', desc: 'If `true`, forward deployment is enabled. Returned only for users with at least the Maintainer role.' }
        expose :ci_forward_deployment_rollback_allowed, documentation: { type: 'Boolean', desc: 'If `true`, rollback is allowed for forward deployments. Returned only for users with at least the Maintainer role.' }
        expose(:ci_job_token_scope_enabled, documentation: { type: 'Boolean', desc: 'If `true`, the CI/CD job token scope is enabled. Returned only for users with at least the Maintainer role.' }) { |p, _| p.ci_outbound_job_token_scope_enabled? }
        expose :ci_separated_caches, documentation: { type: 'Boolean', desc: 'If `true`, CI/CD caches are separated by branch protection status. Returned only for users with at least the Maintainer role.' }
        expose :ci_allow_fork_pipelines_to_run_in_parent_project, documentation: { type: 'Boolean', desc: 'If `true`, fork pipelines can run in the parent project. Can be set only through the API. Returned only for users with at least the Maintainer role.' }
        expose :ci_id_token_sub_claim_components, documentation: { is_array: true, type: 'String', desc: 'Components included in the CI/CD ID token subject claim. Returned only for users with at least the Maintainer role.' }
        expose :build_git_strategy, documentation: { type: 'String', example: 'fetch', desc: 'Git strategy used for CI/CD jobs. Possible values: `fetch` or `clone`. Returned only for users with at least the Maintainer role.' } do |project, options|
          project.build_allow_git_fetch ? 'fetch' : 'clone'
        end
        expose :keep_latest_artifacts_available?, as: :keep_latest_artifact, documentation: { type: 'Boolean', desc: 'If `true`, the latest artifacts are kept when new ones are created. Returned only for users with at least the Maintainer role.' }
        expose(:restrict_user_defined_variables, documentation: { type: 'Boolean', desc: '[Deprecated](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/154510) in GitLab 17.7. Use `ci_pipeline_variables_minimum_override_role` instead. If `true`, user-defined variables are restricted. Returned only for users with at least the Maintainer role.' }) { |p, _| p.restrict_user_defined_variables? }
        expose :ci_pipeline_variables_minimum_override_role, documentation: { type: 'String', desc: 'Minimum role required to override pipeline variables. Returned only for users with at least the Maintainer role.' }
        expose :runner_token_expiration_interval, documentation: { type: 'Integer', example: 3600, desc: 'Expiration interval in seconds for runner authentication tokens. Returned only for users with at least the Maintainer role.' }
        expose :group_runners_enabled, documentation: { type: 'Boolean', desc: 'If `true`, group runners are enabled for the project. Returned only for users with at least the Maintainer role.' }
        expose :resource_group_default_process_mode, documentation: { type: 'String', example: 'unordered', desc: 'Default process mode for resource groups. Returned only for users with at least the Maintainer role.' }
        expose :auto_cancel_pending_pipelines, documentation: { type: 'String', example: 'enabled', desc: 'Setting for automatically canceling pending pipelines. Returned only for users with at least the Maintainer role.' }
        expose :build_timeout, documentation: { type: 'Integer', example: 3600, desc: 'Timeout in seconds for CI/CD jobs. Returned only for users with at least the Maintainer role.' }
        expose :auto_devops_enabled?, as: :auto_devops_enabled, documentation: { type: 'Boolean', desc: 'If `true`, Auto DevOps is enabled for the project. Returned only for users with at least the Maintainer role.' }
        expose :auto_devops_deploy_strategy, documentation: { type: 'String', example: 'continuous', desc: 'Deployment strategy for Auto DevOps. Returned only for users with at least the Maintainer role.' } do |project, options|
          project.auto_devops.nil? ? 'continuous' : project.auto_devops.deploy_strategy
        end
        expose :ci_push_repository_for_job_token_allowed, documentation: { type: 'Boolean', desc: 'If `true`, pushing to the repository with a job token is allowed. Returned only for users with at least the Maintainer role.' }
        expose :protect_merge_request_pipelines, documentation: { type: 'Boolean', desc: 'If `true`, protected CI/CD variables and runners are available in merge request pipelines. Returned only for users with at least the Maintainer role. [Introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/584488) in GitLab 18.10.' }
        expose :ci_display_pipeline_variables, documentation: { type: 'Boolean', desc: 'If `true`, all manually defined variables are displayed on the pipeline details page after a manual pipeline run. Returned only for users with at least the Maintainer role. [Introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/584488) in GitLab 18.10.' }
        expose :ci_skip_branch_pipelines_for_mrs, documentation: { type: 'Boolean', desc: 'If `true`, branch pipelines are skipped when the branch has an open merge request. Returned only for users with at least the Maintainer role.' }
      end

      with_options if: ->(_, _) { Ability.allowed?(options[:current_user], :read_runners_registration_token, project) } do
        # Runner token settings
        expose :runners_token, documentation: { type: 'String', example: 'b8547b1dc37721d05889db52fa2f02', desc: 'Token for registering runners with the project. Returned only for users with at least the Maintainer role, and only if runner registration tokens are enabled.' }
      end

      expose :ci_config_path, documentation: { type: 'String', example: '', desc: 'Path to the CI/CD configuration file.' }, if: ->(project, options) { Ability.allowed?(options[:current_user], :read_code, project) }
      expose :public_builds, as: :public_jobs, documentation: { type: 'Boolean', desc: 'If `true`, job logs and artifacts are publicly accessible.' }

      expose :shared_with_groups, documentation: { is_array: true, type: 'Hash', desc: 'Groups the project is shared with.' } do |project, options|
        user = options[:current_user]

        SharedGroupWithProject.represent(project.visible_group_links(for_user: user), options)
      end

      expose :only_allow_merge_if_pipeline_succeeds, documentation: { type: 'Boolean', desc: 'If `true`, merges are allowed only if the pipeline succeeds.' }
      expose :allow_merge_on_skipped_pipeline, documentation: { type: 'Boolean', desc: 'If `true`, merges are allowed when the pipeline is skipped.' }
      expose :request_access_enabled, documentation: { type: 'Boolean', desc: 'If `true`, users can request access to the project.' }
      expose :only_allow_merge_if_all_discussions_are_resolved, documentation: { type: 'Boolean', desc: 'If `true`, merges are allowed only if all discussions are resolved.' }
      expose :remove_source_branch_after_merge, documentation: { type: 'Boolean', desc: 'If `true`, the source branch is removed after merge by default.' }
      expose :printing_merge_request_link_enabled, documentation: { type: 'Boolean', desc: 'If `true`, a link to create or view a merge request is printed after a push.' }
      expose :merge_method, documentation: { type: 'String', example: 'merge', desc: 'Merge method used for the project. Possible values: `merge`, `rebase_merge`, or `ff`.' }
      expose :squash_option, documentation: { type: 'String', example: 'default_off', desc: 'Squash option for merge requests. Possible values: `never`, `always`, `default_on`, or `default_off`.' }
      expose :automatic_rebase_enabled, documentation: { type: 'Boolean', desc: 'If `true`, the source branch is automatically rebased before merge. [Introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/623568) in GitLab 19.4.' }
      expose :enforce_auth_checks_on_uploads, documentation: { type: 'Boolean', desc: 'If `true`, authentication checks are enforced on uploads.' }
      expose :suggestion_commit_message, documentation: { type: 'String', example: 'Suggestion message', desc: 'Custom commit message for applied suggestions.' }
      expose :merge_commit_template, documentation: { type: 'String', example: '%(title)', desc: 'Template for merge commit messages.' }
      expose :squash_commit_template, documentation: { type: 'String', example: '%(source_branch)', desc: 'Template for squash commit messages.' }
      expose :mr_default_title_template, documentation: { type: 'String', example: '%(source_branch)', desc: 'Template for merge request titles. [Introduced](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/228442) in GitLab 18.11.' }
      expose :issue_branch_template, documentation: { type: 'String', example: '%(title)', desc: 'Template for branch names created from issues.' }
      expose :statistics, using: ::API::Entities::ProjectStatistics, if: ->(project, options) {
        options[:statistics] && Ability.allowed?(options[:current_user], :read_statistics, project)
      }
      expose :warn_about_potentially_unwanted_characters, documentation: { type: 'Boolean', desc: 'If `true`, warnings are shown for potentially unwanted characters.' }

      expose :autoclose_referenced_issues, documentation: { type: 'Boolean', desc: 'If `true`, referenced issues are closed automatically.' }

      expose :max_artifacts_size, documentation: { type: 'Integer', desc: 'Maximum size in MB for CI/CD artifacts.' }

      # rubocop: disable CodeReuse/ActiveRecord
      def self.preload_resource(project)
        ActiveRecord::Associations::Preloader.new(records: [project], associations: { project_group_links: { group: :route } }).call
      end

      def self.preload_relation(projects_relation, options = {})
        # Preloading topics, should be done with using only `:topics`,
        # as `:topics` are defined as: `has_many :topics, through: :project_topics`
        # N+1 is solved then by using `subject.topics.map(&:name)`
        # MR describing the solution: https://gitlab.com/gitlab-org/gitlab-foss/merge_requests/20555
        super(projects_relation).preload(group: :namespace_settings)
                                .preload(:ci_cd_settings)
                                .preload(:project_setting)
                                .preload(:container_expiration_policy)
                                .preload(:auto_devops)
                                .preload(:project_repository)
                                .preload(:service_desk_setting)
                                .preload(project_group_links: { group: :route },
                                  fork_network: :root_project,
                                  fork_network_member: :forked_from_project)
      end
      # rubocop: enable CodeReuse/ActiveRecord

      def self.execute_batch_counting(projects_relation)
        # Call the count methods on every project, so the BatchLoader would load them all at
        # once when the entities are rendered
        projects_relation.each(&:open_issues_count)

        super
      end
    end
  end
end

API::Entities::Project.prepend_mod_with('API::Entities::Project', with_descendants: true)
