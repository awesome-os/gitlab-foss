# frozen_string_literal: true

module API
  module WorkItems
    class RelatedBranches < ::API::Base
      include APIGuard

      allow_access_with_scope :ai_workflows, if: ->(request) { request.get? || request.head? }

      before { authenticate! }
      before { check_work_item_rest_api_feature_flag! }

      feature_category :portfolio_management
      urgency :low

      helpers ::API::Helpers::WorkItems::Authorization
      helpers ::API::Helpers::WorkItems::CursorPagination
      helpers ::API::Helpers::WorkItems::Preloads
      helpers ::API::Helpers::WorkItems::Rendering

      helpers do
        def render_related_branches_for(parent_work_item)
          authorize_work_item_feature!(parent_work_item)
          check_pagination_param!

          project = parent_work_item.project

          # Same service as the GraphQL development widget, so REST tracks it rather than
          # reimplementing. Group-level work items have no project to search.
          branches = project ? related_branches_in(project, parent_work_item) : []

          # Pagination bounds the response, not the work: cost scales with the total matching branch
          # count, not per_page. Sorting by name keeps pages deterministic.
          present paginate_with_offset_cursor(branches.sort_by { |branch| branch[:name] }),
            with: ::API::Entities::WorkItems::Features::RelatedBranch,
            current_user: current_user
        end

        # @note The route takes read_work_item, but a fine-grained token reads a pipeline status with
        #   read_pipeline on the project, as on the pipelines endpoints. When only the public access
        #   rule grants it, the status is built for an anonymous user, as GraphQL does.
        def related_branches_in(project, work_item)
          pipeline_access = ::Authz::Tokens::AuthorizeGranularScopesService.new(
            boundaries: ::Authz::Boundary.for(project), permissions: :read_pipeline,
            token: access_token, allow_public_access: true
          ).execute
          public_access = pipeline_access.success? && pipeline_access.payload[:public_access]

          branches = ::Issues::RelatedBranchesService
            .new(container: project, current_user: current_user)
            .execute(work_item, with_pipeline_status: pipeline_access.success? && !public_access)
          return branches unless public_access

          branches.each { |branch| branch[:pipeline_status] = anonymous_pipeline_status(project, branch) }
        end

        def anonymous_pipeline_status(project, branch)
          pipeline = project.latest_pipeline(branch[:name], branch[:target])
          return unless pipeline && Ability.allowed?(nil, :read_pipeline, pipeline)

          pipeline.detailed_status(nil)
        end
      end

      resource :namespaces do
        params do
          requires :id, types: [String, Integer], desc: 'The ID or URL-encoded full path of the namespace'
        end

        namespace ':id/-/work_items', requirements: { id: FULL_PATH_ID_REQUIREMENT } do
          desc 'List related branches of a work item.' do
            detail 'This feature was introduced in GitLab 19.4. ' \
              'Get a paginated list of branches that reference a work item in a namespace. ' \
              'Project and group namespaces are supported. Group-level work items have no ' \
              'repository to search, so they always return an empty list.'
            hidden true
            success ::API::Entities::WorkItems::Features::RelatedBranch
            failure FAILURE_RESPONSES
            is_array true
            tags WORK_ITEMS_TAGS
          end
          params do
            requires :work_item_iid, type: Integer, desc: 'The internal ID of the work item'
            use :work_items_cursor_pagination_params
          end
          route_setting :lifecycle, :experiment
          route_setting :authorization,
            permissions: :read_work_item,
            boundary: -> { namespace_path_boundary },
            boundaries: [{ boundary_type: :group }, { boundary_type: :project }]
          get ':work_item_iid/related_branches' do
            render_related_branches_for(work_item_for_namespace!(params[:id], params[:work_item_iid]))
          end
        end
      end

      resource :projects do
        params do
          requires :id, types: [String, Integer], desc: 'The ID or URL-encoded path of the project'
        end

        namespace ':id/-/work_items', requirements: { id: FULL_PATH_ID_REQUIREMENT } do
          desc 'List related branches of a work item in a project.' do
            detail 'This feature was introduced in GitLab 19.4. ' \
              'Get a paginated list of branches that reference a work item in a project.'
            hidden true
            success ::API::Entities::WorkItems::Features::RelatedBranch
            failure FAILURE_RESPONSES
            is_array true
            tags WORK_ITEMS_TAGS
          end
          params do
            requires :work_item_iid, type: Integer, desc: 'The internal ID of the work item'
            use :work_items_cursor_pagination_params
          end
          route_setting :lifecycle, :experiment
          route_setting :authorization,
            permissions: :read_work_item,
            boundary_type: :project
          get ':work_item_iid/related_branches' do
            render_related_branches_for(work_item_for!(user_project, params[:work_item_iid]))
          end
        end
      end

      resource :groups do
        params do
          requires :id, types: [String, Integer], desc: 'The ID or URL-encoded path of the group'
        end

        namespace ':id/-/work_items', requirements: { id: FULL_PATH_ID_REQUIREMENT } do
          desc 'List related branches of a work item in a group.' do
            detail 'This feature was introduced in GitLab 19.4. ' \
              'Get a paginated list of branches that reference a work item in a group.'
            hidden true
            success ::API::Entities::WorkItems::Features::RelatedBranch
            failure FAILURE_RESPONSES
            is_array true
            tags WORK_ITEMS_TAGS
          end
          params do
            requires :work_item_iid, type: Integer, desc: 'The internal ID of the work item'
            use :work_items_cursor_pagination_params
          end
          route_setting :lifecycle, :experiment
          route_setting :authorization,
            permissions: :read_work_item,
            boundary_type: :group
          get ':work_item_iid/related_branches' do
            render_related_branches_for(work_item_for!(find_group!(params[:id]), params[:work_item_iid]))
          end
        end
      end
    end
  end
end
