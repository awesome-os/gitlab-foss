# frozen_string_literal: true

class IncreaseCommitShaLimitOnPKnowledgeGraphCodeIndexingTasks < Gitlab::Database::Migration[2.4]
  milestone '19.7'

  disable_ddl_transaction!

  TABLE_NAME = :p_knowledge_graph_code_indexing_tasks

  # SHA-256 commit IDs are 64 characters, SHA-1 are 40.
  def up
    add_text_limit TABLE_NAME, :commit_sha, 64,
      constraint_name: check_constraint_name(TABLE_NAME, :commit_sha, 'max_length_64')

    remove_text_limit TABLE_NAME, :commit_sha,
      constraint_name: check_constraint_name(TABLE_NAME, :commit_sha, 'max_length')
  end

  def down
    # no-op: restoring the 40-character limit would fail if any row has since
    # been written with a SHA-256 commit_sha.
  end
end
