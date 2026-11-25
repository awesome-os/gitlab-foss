# frozen_string_literal: true

class AddPendingDestructionIndexToDuoWorkflowsSessionCapsules < Gitlab::Database::Migration[2.4]
  milestone '19.7'
  disable_ddl_transaction!

  INDEX_NAME = 'index_duo_wf_session_capsules_on_id_pending_destruction'

  def up
    # status 1 is pending_destruction: the cleanup worker batches over these rows.
    add_concurrent_index :duo_workflows_session_capsules, :id, where: 'status = 1', name: INDEX_NAME
  end

  def down
    remove_concurrent_index_by_name :duo_workflows_session_capsules, INDEX_NAME
  end
end
