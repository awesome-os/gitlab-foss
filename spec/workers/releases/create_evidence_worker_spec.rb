# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Releases::CreateEvidenceWorker, feature_category: :release_evidence do
  let_it_be_with_reload(:project) { create(:project) }
  let_it_be(:release) { create(:release, project: project) }
  let_it_be(:pipeline) { create(:ci_pipeline, sha: release.sha, project: project) }

  # support old scheduled workers without pipeline
  it 'creates a new Evidence record' do
    expect_next_instance_of(::Releases::CreateEvidenceService, release, pipeline: nil) do |service|
      expect(service).to receive(:execute).and_call_original
    end

    expect { described_class.new.perform(release.id) }.to change { Releases::Evidence.count }.by(1)
  end

  it 'creates a new Evidence record with pipeline' do
    expect_next_instance_of(::Releases::CreateEvidenceService, release, pipeline: pipeline) do |service|
      expect(service).to receive(:execute).and_call_original
    end

    expect { described_class.new.perform(release.id, pipeline.id) }.to change { Releases::Evidence.count }.by(1)
  end

  context 'when the evidence would exceed the size limit' do
    let(:worker) { described_class.new }

    before do
      stub_application_setting(release_evidence_max_size_bytes: 1)
    end

    it 'does not create an evidence' do
      expect { worker.perform(release.id, pipeline.id) }.not_to change { Releases::Evidence.count }
    end

    it 'logs the measured size and the limit' do
      worker.perform(release.id, pipeline.id)

      expect(worker.logging_extras).to include(
        'extra.releases_create_evidence_worker.skipped_reason' => 'evidence_size_limit_exceeded',
        'extra.releases_create_evidence_worker.gl_project_id' => project.id,
        'extra.releases_create_evidence_worker.evidence_bytes' =>
          Releases::EvidenceSizeLimit.new(release, pipeline: pipeline).served_bytes,
        'extra.releases_create_evidence_worker.limit_bytes' => 1
      )
    end

    context 'when the release_evidence_size_limit feature flag is disabled' do
      before do
        stub_feature_flags(release_evidence_size_limit: false)
      end

      it 'creates an evidence' do
        expect { worker.perform(release.id, pipeline.id) }.to change { Releases::Evidence.count }.by(1)
      end
    end
  end
end
