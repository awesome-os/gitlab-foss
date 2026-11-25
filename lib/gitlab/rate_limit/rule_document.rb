# frozen_string_literal: true

module Gitlab
  module RateLimit
    # Loads the rate limit contract files (config/rate_limits/*.yaml) through
    # labkit-ruby at boot. The contract declares every limiter the application
    # builds and the identifier properties a rule may use. Overrides do not come
    # from a file: they arrive through the labkit rule store.
    #
    # Loading never raises into boot. A rejected contract is logged and the
    # empty document is returned, so every limiter keeps its compiled-in rules.
    module RuleDocument
      CONTRACT_DIR = 'config/rate_limits'

      class << self
        # @return [Labkit::RateLimit::Config::Document]
        def load
          load!(strict: false)
        rescue ::Labkit::RateLimit::Config::Error => e
          ::Gitlab::AppLogger.error(
            message: 'rate_limit_config_rejected', step: e.step, ::Labkit::Fields::ERROR_MESSAGE => e.message
          )
          ::Labkit::RateLimit::Config::Document.empty
        end

        # @note For CI. A rejected contract raises Labkit::RateLimit::Config::Error
        #   with the step that failed.
        # @param strict [Boolean] reject the whole set on any failure instead of dropping a rule with a warning
        # @return [Labkit::RateLimit::Config::Document]
        def load!(strict:)
          ::Labkit::RateLimit::Config::Loader
            .new(strict: strict, logger: ::Gitlab::AppLogger)
            .load(contracts: contract_files)
        end

        # @return [Array<String>] the contract file paths, in load order
        def contract_files
          Dir.glob(Rails.root.join(CONTRACT_DIR, '*.yaml').to_s)
        end
      end
    end
  end
end

::Gitlab::RateLimit::RuleDocument.prepend_mod
