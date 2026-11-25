# frozen_string_literal: true

module ServiceDesk
  # Posts an internal note as the support bot to tell agents that Service Desk
  # skipped something on a ticket. Each throttle key allows one notice per
  # ticket per window, so repeated triggers don't flood the ticket.
  class PostNoticeService
    include Gitlab::Utils::StrongMemoize

    # @param work_item [WorkItem] the ticket to post the notice on
    # @param note [String] the notice text
    # @param throttle_key [Symbol] a rate limit keyed by work item, registered in
    #   {Gitlab::ApplicationRateLimiter::LabkitAdapter::SupportedRateLimits}
    def initialize(work_item, note:, throttle_key:)
      @work_item = work_item
      @note = note
      @throttle_key = throttle_key
    end

    # @return [void]
    def execute
      # Notes::CreateService silently posts a public note when the author lacks
      # :mark_note_as_internal, which the support bot does whenever Service Desk
      # is disabled. External participants could read that, so post nothing.
      return unless can_post_internal_note?
      return if throttled?

      ::Notes::CreateService.new(project, support_bot, noteable: work_item, note: note, internal: true).execute

      nil
    end

    private

    attr_reader :work_item, :note, :throttle_key

    def can_post_internal_note?
      internal_note = ::Note.new(project: project, noteable: work_item, author: support_bot)

      Ability.allowed?(support_bot, :mark_note_as_internal, internal_note)
    end

    def throttled?
      ::Gitlab::ApplicationRateLimiter.throttled?(throttle_key, scope: { work_item: work_item.id })
    end

    def project
      work_item.project
    end

    def support_bot
      Users::Internal.in_organization(project.organization_id).support_bot
    end
    strong_memoize_attr :support_bot
  end
end
