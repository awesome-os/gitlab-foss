# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Ci::RedundantPipelines::PipelineProtection,
  :clean_gitlab_redis_shared_state, :clean_gitlab_redis_queues,
  feature_category: :continuous_integration do
  let_it_be(:project) { create(:project) }
  let_it_be_with_reload(:pipeline) { create(:ci_pipeline, project: project) }
  let_it_be_with_reload(:build) { create(:ci_build, :pending, pipeline: pipeline) }
  let_it_be(:interruptible_build) { create(:ci_build, :pending, :interruptible, pipeline: pipeline) }

  let(:worker) { Ci::RedundantPipelines::ProtectPipelineWorker }

  subject(:protection) { described_class.new(build) }

  def candidate_cache
    Gitlab::Ci::RedundantPipelines::CandidateCache.for(project_id: project.id, ref: pipeline.ref)
  end

  def pipeline_key
    Gitlab::Ci::RedundantPipelines::PipelineKey.of(pipeline)
  end

  it 'protects the pipeline in the cache, then in the database' do
    protection.protect.persist
    worker.drain

    expect(candidate_cache).to be_protected(pipeline_key)
    expect(pipeline.reload).to be_interruptible_protected
  end

  it 'queues no database write when the database already protects the pipeline' do
    Ci::PipelineProcessingData.protect(pipeline)

    expect { protection.protect.persist }.not_to change { worker.jobs.size }
  end

  it 'queues the database write when another call added the marker' do
    candidate_cache.protect(pipeline_key)

    expect { protection.protect.persist }.to change { worker.jobs.size }.by(1)
  end

  it 'protects nothing while the candidates are not cached' do
    stub_feature_flags(ci_redundant_pipeline_candidates_cache: false)

    expect { protection.protect.persist }.not_to change { worker.jobs.size }
    expect(candidate_cache).not_to be_protected(pipeline_key)
  end

  it 'protects nothing for an interruptible build' do
    expect { described_class.new(interruptible_build).protect.persist }.not_to change { worker.jobs.size }
    expect(candidate_cache).not_to be_protected(pipeline_key)
  end
end
