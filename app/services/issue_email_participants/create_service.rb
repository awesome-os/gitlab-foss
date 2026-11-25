# frozen_string_literal: true

module IssueEmailParticipants
  class CreateService < BaseService
    include Gitlab::Utils::StrongMemoize

    MAX_NUMBER_OF_RECORDS = 10

    def execute
      return error_underprivileged unless user_privileged?
      return error_no_participants_added unless emails.present?

      added_emails = add_participants(emails_within_limit)

      if added_emails.any?
        success(added_emails)
      elsif limited_emails.any?
        error_participant_limit_reached
      else
        error_no_participants_added
      end
    end

    private

    def add_participants(emails_to_add)
      return [] if emails_to_add.empty?

      # Charged with the emails we're about to add, so emails that are invalid,
      # over the ticket's slots, or over the daily cap don't use budget. A failed
      # create below still overcounts by one and leaves its slot unused (rare).
      rate_limited = rate_limiter.rate_limit_batch!(emails_to_add.size)
      added_participants = emails_to_add.map { |email| target.issue_email_participants.create(email: email) }
        .select(&:persisted?)

      if rate_limited
        rate_limiter.post_suppression_notice(target) if added_participants.any?
      else
        added_participants.each { |participant| notify(participant) }
      end

      added_participants.map(&:email)
    end

    def emails_within_limit
      emails_by_limit.first
    end

    def limited_emails
      emails_by_limit.last
    end

    # @note Each check counts the email against the namespace's daily cap, so the
    #   candidates are split only once.
    # @return [Array(Array<String>, Array<String>)] emails within the cap, then emails over it
    def emails_by_limit
      candidate_emails.partition { |email| participant_limiter.allow?(email) }
    end
    strong_memoize_attr :emails_by_limit

    # @note Checks only the format: deduplication already removed emails on the
    #   ticket, and creating the participant still enforces uniqueness.
    # @return [Array<String>] valid new emails that fit in the ticket's remaining slots
    def candidate_emails
      valid_emails = deduplicate_and_limit_emails.select { |email| IssueEmailParticipant.valid_email?(email) }

      log_above_limit_count(valid_emails.size - free_slots) if valid_emails.size > free_slots

      valid_emails.first(free_slots)
    end

    def deduplicate_and_limit_emails
      # Compare downcase versions, but use the original email
      emails.uniq(&:downcase).reject { |email| existing_emails.include?(email.downcase) }
        .first(MAX_NUMBER_OF_EMAILS)
    end

    def free_slots
      [MAX_NUMBER_OF_RECORDS - existing_emails.size, 0].max
    end

    def notify(participant)
      Notify.service_desk_new_participant_email(target.id, participant).deliver_later
      Gitlab::Metrics::BackgroundTransaction.current&.add_event(:service_desk_new_participant_email)
    end

    def rate_limiter
      ::ServiceDesk::EmailRateLimiter.new(project)
    end
    strong_memoize_attr :rate_limiter

    def participant_limiter
      ::ServiceDesk::ExternalParticipantLimiter.new(project)
    end
    strong_memoize_attr :participant_limiter

    def existing_emails
      target.email_participants_emails_downcase
    end
    strong_memoize_attr :existing_emails

    def log_above_limit_count(above_limit_count)
      Gitlab::ApplicationContext.with_context(related_class: self.class.to_s, user: current_user, project: project) do
        Gitlab::AppLogger.info({ above_limit_count: above_limit_count })
      end
    end

    def success(added_emails)
      message = add_system_note(added_emails).upcase_first << "."
      message << " " << participant_limit_message if limited_emails.any?

      ServiceResponse.success(message: message, payload: { limited_emails: limited_emails })
    end

    def error_participant_limit_reached
      ServiceResponse.error(
        message: participant_limit_message,
        reason: :participant_limit_reached,
        payload: { limited_emails: limited_emails }
      )
    end

    def participant_limit_message
      format(
        _("Couldn't add %{emails} because the namespace reached its daily limit for new email participants. " \
          "Try again later."),
        emails: limited_emails.to_sentence
      )
    end

    def system_note_text
      _("added %{emails}")
    end

    def error_no_participants_added
      error(_("No email participants were added. Either none were provided, or they already exist."))
    end
  end
end
