# frozen_string_literal: true

module Ci
  module JobFactoryHelpers
    DEFAULT_STAGE_NAME = 'test'

    # Temp job definitions should not change in normal operation;
    # only use this method as a helper in factory definitions.
    def self.mutate_temp_job_definition(job, **new_config)
      # Deep merge is required because job config changes are meant to be cumulative within factories
      updated_config = (job.temp_job_definition&.job_attributes || {}).deep_merge(new_config)

      new_temp_job_definition = ::Ci::JobDefinition.fabricate(
        config: updated_config,
        project_id: job.pipeline.project.id,
        partition_id: job.pipeline.partition_id
      )

      new_temp_job_definition.validate
      config_errors = new_temp_job_definition.errors[:config]
      raise ActiveRecord::RecordInvalid, new_temp_job_definition if config_errors.any?

      job.temp_job_definition = new_temp_job_definition
    end

    # A job without a `ci_stage` joins the pipeline's `test` stage, since stage names are unique per pipeline.
    # Only use this method as a helper in factory definitions.
    def self.assign_default_stage(job, project:, position:, reload_pipeline: false)
      return if job.ci_stage

      job.ci_stage = find_default_stage(job.pipeline, reload_pipeline: reload_pipeline) ||
        add_default_stage(job.pipeline, project: project, position: position)
    end

    def self.find_default_stage(pipeline, reload_pipeline:)
      if pipeline.respond_to?(:reload) && pipeline.persisted?
        pipeline.reload if reload_pipeline
        pipeline.stages.find_by(name: DEFAULT_STAGE_NAME)
      else
        pipeline.stages.find { |stage| stage.name == DEFAULT_STAGE_NAME }
      end
    end

    def self.add_default_stage(pipeline, project:, position:)
      stage = FactoryBot.build(
        :ci_stage,
        pipeline: pipeline,
        project: project,
        name: DEFAULT_STAGE_NAME,
        position: position,
        status: 'created'
      )

      pipeline.stages << stage
      stage
    end

    private_class_method :find_default_stage, :add_default_stage
  end
end
