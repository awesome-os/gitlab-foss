# frozen_string_literal: true

module Gitlab
  module MergeRequests
    # Finds the merge commit of a merge request merged outside GitLab that the target branch refresh
    # couldn't match, because its stored diff head was stale (the source branch refresh hadn't run).
    # Reloading its diff once the head is on the target branch stores an empty diff.
    class EmptiedDiffMergeDetector
      include Gitlab::Utils::StrongMemoize

      # The newest commits come first, so a walk that hits the limit misses the head's merge commit.
      MAX_TARGET_COMMITS = 1_000
      # Larger merge requests stay open, as before this detection.
      MAX_MERGE_REQUEST_COMMITS = 100

      def initialize(merge_request:, previous_diff:)
        @merge_request = merge_request
        @previous_diff = previous_diff
      end

      # Returns the merge commit SHA, or nil when the merge request wasn't merged this way.
      # Callers check the detect_manual_merge_by_emptied_diff feature flag.
      def execute
        return unless emptied_by_landed_head?
        return unless rebased_from_previous_commits?

        merge_commit_sha
      end

      private

      attr_reader :merge_request, :previous_diff

      def new_diff
        merge_request.merge_request_diff
      end

      def repository
        merge_request.target_project.repository
      end

      # An empty diff means its head is already on the target branch. A previous diff that was
      # empty or never stored can't be told apart from a new merge request (gitlab-foss!12711).
      # Project IDs, not projects: the refresh has reset the merge request, so loading them is a query.
      def emptied_by_landed_head?
        merge_request.source_project_id == merge_request.target_project_id &&
          previous_diff.persisted? && previous_diff.state != 'empty' &&
          new_diff.persisted? && new_diff != previous_diff && new_diff.state == 'empty' &&
          new_diff.head_commit_sha.present? && new_diff.start_commit_sha.present?
      end

      # A rebase keeps each commit's author and authored date, so every previous commit must be among the
      # new head's newest first-parent commits. This rules out landing only some of them, like a cherry-pick
      # of the head, and a source branch reset onto the target branch.
      def rebased_from_previous_commits?
        return false unless previous_diff.commits_count.to_i.between?(1, MAX_MERGE_REQUEST_COMMITS)

        identities(previous_commits) == identities(new_commits)
      end

      def identities(commits)
        commits.map { |commit| [commit.author_email, commit.authored_date.to_i] }.tally
      end

      # Not MergeRequestDiff#commits: it reads previous_diff.merge_request, whose inverse association
      # points the merge request's diff back at previous_diff.
      def previous_commits
        previous_diff.merge_request_diff_commits
          .with_users(read_new_commits_table: previous_diff.read_new_commits_table?)
      end

      def merge_commit_sha
        target_commits = repository.commits_between(
          new_head.id, new_diff.start_commit_sha, limit: MAX_TARGET_COMMITS
        )
        return if target_commits.size >= MAX_TARGET_COMMITS

        Gitlab::BranchPushMergeCommitAnalyzer
          .new(target_commits.reverse + [new_head], relevant_commit_ids: [new_head.id])
          .get_merge_commit(new_head.id)
      end

      def new_head
        new_commits.first
      end

      def new_commits
        repository.commits(new_diff.head_commit_sha, limit: previous_diff.commits_count, first_parent: true)
      end
      strong_memoize_attr :new_commits
    end
  end
end
