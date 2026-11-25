# frozen_string_literal: true

require_relative '../support/helpers/ci/job_factory_helpers'

FactoryBot.define do
  factory :commit_status, class: 'CommitStatus' do
    name { 'default' }
    stage_idx { 0 }
    status { 'success' }
    description { 'commit status' }
    pipeline { association(:ci_pipeline, **@overrides.slice(:project).compact) }
    started_at { 'Tue, 26 Jan 2016 08:21:42 +0100' }
    finished_at { 'Tue, 26 Jan 2016 08:23:42 +0100' }
    partition_id { pipeline&.partition_id }

    before(:create) do |commit_status, evaluator|
      Ci::JobFactoryHelpers.assign_default_stage(
        commit_status, project: commit_status.project || evaluator.project, position: evaluator.stage_idx)
    end

    trait :success do
      status { 'success' }
    end

    trait :failed do
      status { 'failed' }
    end

    trait :canceling do
      status { 'canceling' }
    end

    trait :canceled do
      status { 'canceled' }
    end

    trait :skipped do
      status { 'skipped' }
    end

    trait :running do
      status { 'running' }
    end

    trait :waiting_for_callback do
      status { 'waiting_for_callback' }
    end

    trait :pending do
      status { 'pending' }
    end

    trait :waiting_for_resource do
      status { 'waiting_for_resource' }
    end

    trait :preparing do
      status { 'preparing' }
    end

    trait :created do
      status { 'created' }
    end

    trait :manual do
      status { 'manual' }
    end

    trait :scheduled do
      status { 'scheduled' }
    end

    after(:build) do |build, evaluator|
      build.project ||= build.pipeline.project
    end
  end
end
