# frozen_string_literal: true

class RemoveUnusedExternalAgentColumnsFromDuoWorkflowsWorkflows < Gitlab::Database::Migration[2.4]
  disable_ddl_transaction!
  milestone '19.7'

  def up
    # no-op: an Org Mover publication depends on these columns, so removing them failed.
    # https://gitlab.com/gitlab-com/gl-infra/production-engineering/-/work_items/30419
  end

  def down
    # no-op
  end
end
