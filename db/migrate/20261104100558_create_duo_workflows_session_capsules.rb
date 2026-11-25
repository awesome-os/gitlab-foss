# frozen_string_literal: true

class CreateDuoWorkflowsSessionCapsules < Gitlab::Database::Migration[2.4]
  milestone '19.6'

  def change
    create_table :duo_workflows_session_capsules do |t|
      t.timestamps_with_timezone null: false
      t.datetime_with_timezone :expire_at, null: false
      # Loose foreign key instead of a cascade: deleting the session marks the row pending_destruction,
      # so a cleanup worker can delete the row and its file.
      t.bigint :workflow_id, null: false
      t.bigint :namespace_id, null: false, index: true
      t.bigint :size, null: false
      t.integer :file_store, limit: 2, default: 1, null: false
      t.integer :status, limit: 2, default: 0, null: false
      t.text :thread_ts, limit: 255
      t.text :file, null: false, limit: 255

      # The default name would exceed the 63-character limit.
      t.index [:workflow_id, :created_at, :id], order: { created_at: :desc, id: :desc },
        name: 'index_duo_wf_session_capsules_on_workflow_id_created_at_id'
      t.index :expire_at
    end
  end
end
