# frozen_string_literal: true

module QA
  module Tools
    module Ci
      # Decides whether a pipeline skips E2E, runs the full suite, or can select specs
      class E2eSelectionDecision
        include Helpers

        SKIP_LABEL = "pipeline:skip-e2e"
        RUN_ALL_LABEL = "pipeline:run-all-e2e"
        SELECTIVE_TIERS = %w[pipeline::tier-2 pipeline::tier-3].freeze

        MESSAGES = {
          skip_label: "Merge request has pipeline:skip-e2e label, e2e test execution will be skipped.",
          quarantine: "Skipping e2e test execution because only quarantine changes detected in merge request!",
          spec_removal: "Skipping e2e test execution because only e2e spec removal detected in merge request!",
          non_e2e_changes: "Skipping e2e test execution because only non e2e test changes detected in merge request!",
          run_all_label: "Merge request has pipeline:run-all-e2e label, full test suite will be executed",
          empty_diff: "No changed file diff provided, full test suite will be executed",
          framework_changes: "Merge request contains qa framework changes, full test suite will be executed",
          feature_flags: "Feature flag changes detected, full test suite will be executed"
        }.freeze
        NOOP_REASONS = %i[skip_label quarantine spec_removal non_e2e_changes].freeze
        FULL_SUITE_REASONS = %i[run_all_label empty_diff framework_changes feature_flags].freeze

        # @param mr_labels [Array<String>]
        # @param mr_diff [Proc] returns the MR changes, skipped when the skip label is set
        def initialize(mr_labels:, mr_diff:)
          if mr_labels.include?(SKIP_LABEL) && mr_labels.include?(RUN_ALL_LABEL)
            raise ArgumentError,
              "cannot have both #{RUN_ALL_LABEL} and #{SKIP_LABEL} labels. Please remove one of these labels"
          end

          @mr_labels = mr_labels
          @mr_diff_loader = mr_diff
        end

        def changes
          @changes ||= QaChanges.new(mr_diff)
        end

        # @return [Symbol] why E2E runs the way it does
        def reason
          @reason ||= find_reason.tap { |reason| logger.info(MESSAGES[reason]) if MESSAGES.key?(reason) }
        end

        def message
          MESSAGES.fetch(reason)
        end

        def noop?
          NOOP_REASONS.include?(reason)
        end

        def selective?
          reason == :selective
        end

        # @return [Array<String>] specs for the first pipeline pass, empty runs the full suite
        def tests
          @tests ||= FULL_SUITE_REASONS.include?(reason) ? [] : changes.qa_tests
        end

        # @return [String, nil] flag states for the QA_FEATURE_FLAGS variable
        def feature_flags
          return @feature_flags if defined?(@feature_flags)

          @feature_flags = mr_diff.empty? ? nil : ff_changes.fetch
        end

        def pipeline_tier
          (mr_labels & SELECTIVE_TIERS).first
        end

        private

        attr_reader :mr_labels

        def mr_diff
          @mr_diff ||= @mr_diff_loader.call
        end

        def find_reason
          return :skip_label if mr_labels.include?(SKIP_LABEL)
          return :run_all_label if mr_labels.include?(RUN_ALL_LABEL)
          return :empty_diff if mr_diff.empty?
          return :quarantine if changes.quarantine_changes?
          return :spec_removal if changes.only_spec_removal?
          return :non_e2e_changes if changes.only_changes_to_non_e2e_spec_files?
          return :framework_changes if changes.framework_changes?
          # Deleted flags skip the flag job, new flags run mapped specs
          return :feature_flags if feature_flags && !ff_changes.only_additions_or_deletions?
          return :not_eligible unless selective_eligible?

          :selective
        end

        def ff_changes
          @ff_changes ||= FfChanges.new(mr_diff)
        end

        def selective_eligible?
          selective_enabled = QA::Runtime::Env.selective_execution_improved_enabled?
          frontend_selective_enabled = QA::Runtime::Env.frontend_selective_execution_enabled?
          targeting_stable = QA::Runtime::Env.mr_targeting_stable_branch?
          eligible = !pipeline_tier.nil? && (selective_enabled || frontend_selective_enabled) && !targeting_stable

          logger.info("=== Selective Execution Decision Point ===")
          logger.info("Selective execution improved enabled: #{selective_enabled}")
          logger.info("Frontend selective execution enabled: #{frontend_selective_enabled}")
          logger.info("MR targeting stable branch: #{targeting_stable}")
          logger.info("Pipeline tier: #{pipeline_tier.inspect}")
          logger.info("Will run improved selective execution: #{eligible}")
          eligible
        end
      end
    end
  end
end
