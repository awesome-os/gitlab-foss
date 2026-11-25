# frozen_string_literal: true

module MergeRequests
  # Whether a fresh merge ref changes its target exactly as the latest regular diff changes
  # its merge base. Then a merge-head diff would only repeat the regular diff, which every
  # reader already falls back to when a merge request has no merge-head diff.
  class MergeHeadDiffMatchService
    include Gitlab::Utils::StrongMemoize

    # @param merge_ref [Hash] the commit_id, target_id and source_id MergeToRefService returned
    def initialize(merge_request, merge_ref)
      @merge_request = merge_request
      @merge_ref = merge_ref
    end

    def match?
      outcome == :matches_regular_diff
    end

    # Why #match? decided as it did. Only logged during the rollout.
    def outcome
      return :regular_diff_not_collected unless regular_diff.collected?
      return :no_merge_base if regular_diff.base_commit_sha.blank?
      return :source_moved unless regular_diff.head_commit_sha == merge_ref[:source_id]
      return :changes_differ unless regular_diff_changes == merge_ref_changes

      :matches_regular_diff
    # Gitaly's INVALID_ARGUMENT reaches us as ArgumentError, not a Gitlab::Git::BaseError.
    rescue Gitlab::Git::BaseError, ArgumentError
      :git_error
    end
    strong_memoize_attr :outcome

    private

    attr_reader :merge_request, :merge_ref

    def regular_diff
      merge_request.merge_request_diff
    end

    def regular_diff_changes
      changes(regular_diff.base_commit_sha, regular_diff.head_commit_sha)
    end

    def merge_ref_changes
      changes(merge_ref[:target_id], merge_ref[:commit_id])
    end

    # Equal blob pairs per path give equal diffs. Uses the raising call, because the other
    # one returns no changes on a Gitaly error, so two failures would compare equal.
    def changes(from, to)
      merge_request.project.repository.raw_repository
        .find_changed_paths!([Gitlab::Git::DiffTree.new(from, to)])
        .to_set do |change|
          [change.path, change.status, change.old_mode, change.new_mode, change.old_blob_id, change.new_blob_id]
        end
    end
  end
end
