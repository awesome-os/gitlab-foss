# frozen_string_literal: true

require "gitlab/glaz"

module Gitlab
  module PolicyStore
    # Parses a Rego program through the GLAZ engine before it is stored, so a program that
    # cannot be parsed is refused at save time with the parse error and its location.
    module RegoValidator
      extend self

      # Defensive cap. Engine messages are short today, but if a future release quotes
      # the source, this keeps the full program out of the response and logs.
      MAX_REPORTED_ERROR_BYTES = 1_000

      # The module all rules merge into. Every authored part of it already parsed on its own,
      # so a failure here is a defect in the merge, not something the caller can correct.
      MERGED_PROGRAM_FIELD = :policy_merged_program

      VIOLATION_DETAIL_KEYS = %i[path expected].freeze

      # @param field [String, Symbol] what the program is, for the error message
      # @param program [String] Rego source
      # @param trigger [String, nil] the policy's trigger, whose context schema the engine checks the
      #   program's violation details against
      # @raise [Gitlab::PolicyStore::ValidationError] if an authored program does not parse, or its
      #   violation details do not fit the trigger's schema
      # @raise [Gitlab::PolicyStore::EngineError] if the engine faults, or the merged module is refused
      # @return [Array<Hash>] the program's violation details as `{ path:, expected: }` entries,
      #   without `expected` when the program names no value for the path
      def validate!(field, program, trigger: nil)
        result = engine.validate(policy_rego: program, trigger: trigger)
        raise PolicyStore::EngineError, "#{field} could not be validated" unless result.is_a?(Hash)
        return violation_details(result[:violation_details]) if result[:valid]

        errors = result[:errors]
        errors = [] unless errors.is_a?(Array)
        detail = reported_errors(errors)
        raise PolicyStore::EngineError, "#{field} could not be validated" if detail.empty?

        raise invalid_program_error(field), "#{field} is invalid: #{detail}"
      rescue EncodingError
        raise invalid_program_error(field), "#{field} must be valid UTF-8"
      rescue PolicyStore::Error
        raise
      rescue StandardError
        raise PolicyStore::EngineError, "#{field} could not be validated"
      end

      private

      # Stored under a schema that allows only these keys and no null, so anything else is dropped.
      def violation_details(details)
        Array(details).map { |detail| detail.slice(*VIOLATION_DETAIL_KEYS).compact }
      end

      def engine
        ::Gitlab::Glaz.govern_policy_engine
      end

      def invalid_program_error(field)
        field.to_sym == MERGED_PROGRAM_FIELD ? PolicyStore::EngineError : PolicyStore::ValidationError
      end

      def reported_errors(errors)
        errors.map do |error|
          message = truncated(error[:message].to_s, MAX_REPORTED_ERROR_BYTES)
          location = error[:location].to_s.strip

          location.empty? ? message : "#{message} (at #{location})"
        end.join("; ")
      end

      def truncated(text, limit)
        return text if text.bytesize <= limit

        "#{text.byteslice(0, limit).scrub('')}..."
      end
    end
  end
end
