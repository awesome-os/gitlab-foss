# frozen_string_literal: true

namespace :ci do
  desc "Detect changes and generate e2e test pipelines with dynamically scaled parallel jobs"
  task :generate_e2e_pipelines, [:pipeline_path] do |_, args|
    require_relative "helpers/util"

    include Task::Helpers::Util
    include QA::Tools::Ci::Helpers

    logger.info("*** Analyzing which E2E tests to execute based on MR changes or Scheduled pipeline ***")

    pipeline_path = args[:pipeline_path] || "tmp"
    decision = QA::Tools::Ci::E2eSelectionDecision.new(mr_labels: mr_labels, mr_diff: -> { mr_diff })
    record_selection = ->(reason, selected_specs = []) do
      QA::Tools::Ci::E2eSelectionRecorder.new(
        pipeline_tier: decision.pipeline_tier,
        # The skip label decision avoids fetching the MR diff
        changed_files: reason == :skip_label ? [] : decision.changes.changed_files,
        selected_specs: selected_specs,
        decision_reason: reason
      ).record
    end

    if decision.noop?
      noop_pipeline_creator = QA::Tools::Ci::PipelineCreator.new([], pipeline_path: pipeline_path, logger: logger)
      noop_pipeline_creator.create_noop(reason: decision.message)
      next record_selection.call(decision.reason)
    end

    logger.info("Following specs were selected for execution: '#{decision.tests}'") if decision.tests.any?

    creator_args = {
      pipeline_path: pipeline_path,
      logger: logger,
      env: { "QA_FEATURE_FLAGS" => decision.feature_flags }
    }
    pipeline_creator = QA::Tools::Ci::PipelineCreator.new(decision.tests, **creator_args)

    logger.info("*** Creating Functional E2E test pipeline definitions ***")
    pipeline_creator.create
    logger.info("*** Creating Non-Functional E2E test pipeline definitions ***")
    pipeline_creator.create_non_functional
    next record_selection.call(decision.reason, decision.tests) unless decision.selective?

    pipelines_for_selective_improved = [:test_on_cng]
    logger.warn("*** Recreating #{pipelines_for_selective_improved} using spec list based on coverage mappings ***")
    begin
      tests_from_mapping = decision.changes.qa_tests(from_code_path_mapping: true)
      logger.info("Following specs were selected for execution: '#{tests_from_mapping}'")
      QA::Tools::Ci::PipelineCreator.new(tests_from_mapping, **creator_args).create(pipelines_for_selective_improved)
      # An empty list runs the full suite, so nothing was selected
      if tests_from_mapping.any?
        record_selection.call(decision.reason, tests_from_mapping)
      elsif decision.changes.dependency_changes
        record_selection.call(:dependency_changes)
      else
        record_selection.call(:mapping_empty)
      end
    rescue StandardError => e
      logger.warn("*** Error while creating pipeline with selected specs: #{e.message} #{e.backtrace} ***")
      logger.info("*** Defaulting to running full suite ***")
      QA::Tools::Ci::PipelineCreator.new([], **creator_args).create
      record_selection.call(:mapping_error)
    end
  end

  desc "Export backend code paths mapping to GCP"
  task :export_code_paths_mapping, [:glob] do |_, args|
    raise("Code paths mapping JSON glob pattern is required") unless args[:glob]

    QA::Tools::Ci::CodePathsMapping.export(args[:glob])
  end

  desc "Export frontend code paths mapping to GCP"
  task :export_frontend_code_paths_mapping, [:glob] do |_, args|
    raise("Code paths mapping JSON glob pattern is required") unless args[:glob]

    # The job allows failure, so this warns without breaking the schedule
    raise("No coverage files matched #{args[:glob]}, assets likely not instrumented") if Dir.glob(args[:glob]).empty?

    filename = File.basename(args[:glob])
    prefix = "#{filename.split('*').first}merged-pipeline"
    QA::Tools::Ci::CodePathsMapping.export(args[:glob], bucket: "code-path-mappings",
      file_name: prefix)
  end
end
