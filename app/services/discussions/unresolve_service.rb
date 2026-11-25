# frozen_string_literal: true

module Discussions
  class UnresolveService < Discussions::BaseService
    include Gitlab::Utils::StrongMemoize
    prepend RateLimitedService

    rate_limit key: :discussions_resolve, opts: { scope: { user: :current_user } }

    def initialize(discussion, user)
      @discussion = discussion
      @user = user

      super
    end

    def execute
      @all_discussions_resolved_before = merge_request ? @discussion.noteable.discussions_resolved? : false

      @discussion.unresolve!

      send_graphql_triggers
      execute_merge_request_hooks

      Gitlab::UsageDataCounters::MergeRequestActivityUniqueCounter
        .track_unresolve_thread_action(user: @user)
    end

    private

    def merge_request
      @discussion.noteable if @discussion.for_merge_request?
    end
    strong_memoize_attr :merge_request

    def send_graphql_triggers
      return unless merge_request && @all_discussions_resolved_before

      GraphqlTriggers.merge_request_merge_status_updated(merge_request)
    end

    def execute_merge_request_hooks
      return unless merge_request

      MergeRequests::UnresolvedDiscussionNotificationService
        .new(project: merge_request.project, current_user: @user)
        .execute(merge_request, all_discussions_resolved_before: @all_discussions_resolved_before)
    end
  end
end
