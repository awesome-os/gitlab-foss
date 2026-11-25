# frozen_string_literal: true

module Types
  module WorkItems
    # Disabling widget level authorization as it might be too granular
    # and we already authorize the parent work item
    # rubocop:disable Graphql/AuthorizeTypes -- reason above
    class RelatedBranchType < BaseObject
      graphql_name 'WorkItemRelatedBranch'

      # Branch names, and the default branch in compare_path, are read_branch data, as on the Branch type.
      authorize_granular_token parent_authorizes: :read_branch

      field :name,
        GraphQL::Types::String,
        null: false,
        description: 'Name of the branch.'

      field :compare_path, GraphQL::Types::String, null: true,
        description: 'Path to comparison of branch to default branch.'

      field :pipeline_status, ::Types::Ci::DetailedStatusType, null: true,
        description: 'Status of pipeline for the branch.',
        directives: granular_scope_directive(permissions: :read_pipeline, boundary: :project, boundary_type: :project)

      # Resolved here rather than by the development widget, so that the status is built for
      # the user this field is served as, which its granular token check can change.
      def pipeline_status
        pipeline = object.project.latest_pipeline(object.name, object.target)
        return unless pipeline && Ability.allowed?(current_user, :read_pipeline, pipeline)

        pipeline.detailed_status(current_user)
      end
    end
    # rubocop:enable Graphql/AuthorizeTypes
  end
end
