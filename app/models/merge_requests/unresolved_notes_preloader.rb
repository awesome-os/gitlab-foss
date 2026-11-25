# frozen_string_literal: true

module MergeRequests
  # `MergeRequest#mergeable_discussions_state?` checks for unresolved notes only when the project
  # requires resolved threads, so this checks them only for merge requests of those projects.
  class UnresolvedNotesPreloader
    def initialize(merge_requests)
      @merge_requests = merge_requests
    end

    def execute
      merge_requests = merge_requests_requiring_resolved_discussions
      return if merge_requests.empty?

      ids_with_unresolved_notes = Note.unresolved.where(noteable: merge_requests).distinct
        .pluck(:noteable_id).to_set # rubocop:disable Database/AvoidUsingPluckWithoutLimit -- at most one id for each merge request of the page

      merge_requests.each do |merge_request|
        merge_request.has_unresolved_notes = ids_with_unresolved_notes.include?(merge_request.id)
      end
    end

    private

    def merge_requests_requiring_resolved_discussions
      @merge_requests.group_by(&:target_project_id).flat_map do |_, merge_requests|
        merge_requests.first.only_allow_merge_if_all_discussions_are_resolved? ? merge_requests : []
      end
    end
  end
end
