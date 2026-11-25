# frozen_string_literal: true

module Resolvers
  class CodequalityReportsComparerResolver < BaseResolver
    include Gitlab::Graphql::Authorize::AuthorizeResource

    type ::Types::Security::CodequalityReportsComparerType, null: true

    authorize :read_build
    authorize_granular_token permissions: :read_job, boundary: :project, boundary_type: :project

    def resolve
      return unless object.diff_head_pipeline

      authorize!(object.diff_head_pipeline)

      object.compare_codequality_reports(current_user)
    end
  end
end
