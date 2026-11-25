# frozen_string_literal: true

module MergeRequests
  class ResolvedDiscussionNotificationService < MergeRequests::BaseService
    def execute(merge_request, send_notifications: true)
      return unless merge_request.discussions_resolved?

      SystemNoteService.resolve_all_discussions(merge_request, project, current_user)
      execute_hooks(merge_request, 'update')
      publish_discussions_resolved_event(merge_request)

      return unless send_notifications

      notification_service.async.resolve_all_discussions(merge_request, current_user)
    end

    private

    def publish_discussions_resolved_event(merge_request)
      # A diff reload without a user (branch change) re-checks mergeability itself.
      return unless current_user
      return unless merge_request.auto_merge_enabled?

      Gitlab::EventStore.publish(
        MergeRequests::DiscussionsResolvedEvent.new(
          data: { current_user_id: current_user.id, merge_request_id: merge_request.id }
        )
      )
    end
  end
end
