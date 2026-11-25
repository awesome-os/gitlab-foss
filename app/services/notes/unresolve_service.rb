# frozen_string_literal: true

module Notes
  class UnresolveService < ::BaseService
    prepend RateLimitedService

    rate_limit key: :discussions_resolve, opts: { scope: { user: :current_user } }

    def execute(note)
      merge_request = note.noteable if note.noteable.is_a?(MergeRequest)
      all_discussions_resolved_before = merge_request.present? && note.resolved? &&
        merge_request.discussions_resolved?

      note.unresolve!

      return unless merge_request

      ::MergeRequests::UnresolvedDiscussionNotificationService
        .new(project: project, current_user: current_user)
        .execute(merge_request, all_discussions_resolved_before: all_discussions_resolved_before)
    end
  end
end
