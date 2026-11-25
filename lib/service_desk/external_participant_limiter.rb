# frozen_string_literal: true

module ServiceDesk
  # Caps the distinct external participants a top-level namespace can add to
  # Service Desk tickets per day. Every subgroup and project under the
  # namespace shares the cap. Callers check only participants added by group
  # members or the support bot, never ticket authors who email in.
  class ExternalParticipantLimiter
    include Gitlab::Utils::StrongMemoize
    include ::Gitlab::Loggable

    RATE_LIMIT_KEY = :service_desk_external_participants_per_day
    NOTICE_THROTTLE_KEY = :service_desk_external_participant_limit_notice
    NO_LIMIT = 0

    # @param project [Project] the project the participant is added in
    def initialize(project)
      @project = project
    end

    # @note An email already counted today doesn't count again, and is allowed
    #   even after the cap is reached. A refused email is not counted.
    # @param email [String]
    # @return [Boolean] whether the email can be added as a participant
    def allow?(email)
      return true unless limited?
      return true unless throttled?(email)

      log_limit_reached

      false
    end

    # @note For paths where no user sees the error, like CC addresses on inbound email.
    # @param work_item [WorkItem] the ticket whose agents are told participants were skipped
    # @return [void]
    def post_limit_notice(work_item)
      ::ServiceDesk::PostNoticeService.new(
        work_item,
        note: limit_notice_text,
        throttle_key: NOTICE_THROTTLE_KEY
      ).execute
    end

    private

    attr_reader :project

    def limited?
      Feature.enabled?(:service_desk_external_participant_limit, root_namespace) && daily_limit != NO_LIMIT
    end

    # @note Overridden in EE.
    # @return [Integer] the daily cap, or NO_LIMIT
    def daily_limit
      NO_LIMIT
    end

    def throttled?(email)
      ::Gitlab::ApplicationRateLimiter.throttled?(
        RATE_LIMIT_KEY,
        scope: { namespace: root_namespace },
        # A keyed digest keeps email addresses out of Redis. A db_key_base rotation
        # changes it, so an email counted earlier that day can take a second slot.
        distinct_value: ::Gitlab::CryptoHelper.sha256(email.downcase),
        threshold: daily_limit
      )
    end

    def log_limit_reached
      ::Gitlab::AppJsonLogger.warn(
        build_structured_payload_labkit(
          Labkit::Fields::LOG_MESSAGE => 'Service Desk external participant limit reached',
          Labkit::Fields::GL_ROOT_NAMESPACE_ID => root_namespace.id,
          Labkit::Fields::GL_NAMESPACE_ID => project.namespace_id,
          Labkit::Fields::GL_PROJECT_ID => project.id,
          Labkit::Fields::ADDITIONAL_DETAILS => "daily_limit: #{daily_limit}"
        )
      )
    end

    def limit_notice_text
      s_(
        'ServiceDesk|GitLab did not add some email addresses as participants on this ticket ' \
          'because the namespace reached its daily limit for new email participants.'
      )
    end

    def root_namespace
      project.root_namespace
    end
    strong_memoize_attr :root_namespace
  end
end

ServiceDesk::ExternalParticipantLimiter.prepend_mod
