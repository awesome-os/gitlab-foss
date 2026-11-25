# frozen_string_literal: true

module ServiceDesk
  class EmailRateLimiter
    include Gitlab::Utils::StrongMemoize

    HOURLY_LIMIT_NAME = ::Gitlab::Email::NamespaceRateLimiter::HOURLY_THRESHOLD_LIMIT_NAME
    DAILY_LIMIT_NAME = ::Gitlab::Email::NamespaceRateLimiter::DAILY_THRESHOLD_LIMIT_NAME
    SERVICE_DESK_EMAIL_RATE_LIMIT_FEATURE_FLAG = :service_desk_email_rate_limit

    def initialize(project)
      @project = project
    end

    def rate_limit_batch!(count)
      limiter.rate_limit_batch!(count)
    end

    def post_suppression_notice(work_item)
      ::ServiceDesk::PostNoticeService.new(
        work_item,
        note: suppression_notice_text,
        throttle_key: :service_desk_suppression_notice
      ).execute
    end

    private

    attr_reader :project

    def limiter
      ::Gitlab::Email::NamespaceRateLimiter.new(
        root_namespace: project.root_namespace,
        hourly_bucket: HOURLY_LIMIT_NAME,
        daily_bucket: DAILY_LIMIT_NAME,
        feature_flag: SERVICE_DESK_EMAIL_RATE_LIMIT_FEATURE_FLAG,
        log_message: 'Service Desk outbound email rate limit exceeded',
        log_context: {
          Labkit::Fields::CLASS_NAME => self.class.name,
          Labkit::Fields::GL_NAMESPACE_ID => project.namespace_id,
          Labkit::Fields::GL_PROJECT_ID => project.id
        },
        # Service Desk suppresses the batch that trips the window (hard cap),
        # unlike the new large-recipient features which allow one overshoot.
        #
        overshoot: :hard_cap,
        plan_limits: -> { plan_limits }
      )
    end
    strong_memoize_attr :limiter

    # Overridden in EE
    def plan_limits
      project.root_namespace.actual_limits
    end

    def suppression_notice_text
      s_(
        'ServiceDesk|GitLab has not sent Service Desk emails for recent activity on this ' \
          'ticket because the namespace exceeded its Service Desk email rate limit. ' \
          'Emails resume automatically when the rate falls below the limit.'
      )
    end
  end
end

ServiceDesk::EmailRateLimiter.prepend_mod
