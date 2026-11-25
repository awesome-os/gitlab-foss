# frozen_string_literal: true

require 'spec_helper'
require_migration!

RSpec.describe FinalizeBackfillImportedDiffCommitsToPartitioned, migration: :gitlab_main_org,
  feature_category: :code_review_workflow do
  it 'finalizes the batched background migration' do
    expect(described_class).to ensure_batched_background_migration_is_finished_for(
      job_class_name: 'BackfillImportedDiffCommitsToPartitioned',
      table_name: :merge_request_diffs,
      column_name: :id,
      job_arguments: ['merge_request_diff_commits_archived', 'merge_request_diff_commits', 27_951_444, 31_189_569],
      finalize: true,
      skip_early_finalization_validation: true
    )

    migrate!
  end
end
