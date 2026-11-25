# frozen_string_literal: true

module MergeRequests
  class UnresolvedDiscussionNotificationService < MergeRequests::BaseService
    # @note The pre-unresolve state cannot be recovered here, so callers capture it.
    #   Gating on the 0 -> 1 transition keeps receivers to one event per merge request,
    #   not one per thread.
    def execute(merge_request, all_discussions_resolved_before:)
      return unless all_discussions_resolved_before

      # The payload reads unresolved_notes, which can still be cached from before the unresolve.
      merge_request.unresolved_notes.reset
      execute_hooks(merge_request, 'update')
    end
  end
end
