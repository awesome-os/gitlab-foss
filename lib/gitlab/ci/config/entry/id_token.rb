# frozen_string_literal: true

module Gitlab
  module Ci
    class Config
      module Entry
        ##
        # Entry that represents a JWT definition.
        #
        class IdToken < ::Gitlab::Config::Entry::Node
          include ::Gitlab::Config::Entry::Attributable
          include ::Gitlab::Config::Entry::Validatable

          TARGET_AUDIENCE_MAX_LENGTH = 255

          attributes %i[aud target_audience]

          validations do
            validates :config, required_keys: %i[aud], allowed_keys: %i[aud target_audience]
            validates :aud, array_of_strings_or_string: true
            validates :target_audience, type: String, length: { in: 1..TARGET_AUDIENCE_MAX_LENGTH }, allow_nil: true
          end

          def value
            { aud: aud, target_audience: target_audience }.compact
          end
        end
      end
    end
  end
end
