# frozen_string_literal: true

module Gitlab
  module BackgroundMigration
    # Nullifies `namespace_id` on scan_result_policies rows where `project_id` is also set, so that each
    # row has exactly one sharding key column set.
    class NullifyNamespaceIdOnScanResultPolicies < BatchedMigrationJob
      cursor :id
      operation_name :nullify_namespace_id_on_scan_result_policies
      feature_category :security_policy_management

      def perform
        each_sub_batch do |sub_batch|
          # Filtering sub_batch directly would apply its LIMIT after the filters and scan the whole job range.
          sub_batch.klass
            .where(id: sub_batch.select(:id))
            .where.not(namespace_id: nil)
            .where.not(project_id: nil)
            .update_all(namespace_id: nil)
        end
      end
    end
  end
end
