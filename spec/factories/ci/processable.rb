# frozen_string_literal: true

require_relative '../../support/helpers/ci/job_factory_helpers'

FactoryBot.define do
  factory :ci_processable, class: 'Ci::Processable' do
    name { 'processable' }
    stage_idx { ci_stage.try(:position) || 0 }
    ref { 'master' }
    tag { false }
    pipeline { association(:ci_pipeline, **@overrides.slice(:project).compact) }
    project { pipeline.project }
    scheduling_type { 'stage' }
    partition_id { pipeline.partition_id }

    transient do
      options { {} }
      yaml_variables { [] }
    end

    after(:stub, :build) do |processable, evaluator|
      Ci::JobFactoryHelpers.mutate_temp_job_definition(
        processable, options: evaluator.options, yaml_variables: evaluator.yaml_variables)
    end

    after(:build) do |processable, evaluator|
      Ci::JobFactoryHelpers.assign_default_stage(
        processable,
        project: processable.project || evaluator.project,
        position: evaluator.stage_idx,
        reload_pipeline: true
      )
    end

    before(:create) do |processable|
      if processable.temp_job_definition
        Gitlab::Ci::Pipeline::Create::JobDefinitionBuilder.new(processable.pipeline, [processable]).run
      end
    end

    after(:create) do |processable, evaluator|
      # job_definition_instance is assigned when we run JobDefinitionBuilder
      next unless processable.job_definition_instance

      processable.association(:job_definition).reload
      processable.temp_job_definition = nil
    end

    trait :without_job_definition do
      after(:build) do |processable, evaluator|
        processable.temp_job_definition = nil
      end
    end

    trait :waiting_for_resource do
      status { 'waiting_for_resource' }
    end

    trait :resource_group do
      waiting_for_resource_at { 5.minutes.ago }
      resource_group { association(:ci_resource_group, project: project) }
    end

    trait :interruptible do
      after(:build) do |processable|
        Ci::JobFactoryHelpers.mutate_temp_job_definition(processable, interruptible: true)
      end
    end
  end
end
