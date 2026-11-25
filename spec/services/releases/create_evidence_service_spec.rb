# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Releases::CreateEvidenceService, feature_category: :release_orchestration do
  let_it_be_with_reload(:project) { create(:project) }

  let(:release) { create(:release, project: project) }
  let(:service) { described_class.new(release) }

  it 'creates evidence' do
    expect { service.execute }.to change { release.reload.evidences.count }.by(1)
  end

  it 'saves evidence summary' do
    service.execute
    evidence = Releases::Evidence.last

    expect(release.tag).not_to be_nil
    expect(evidence.summary["release"]["tag_name"]).to eq(release.tag)
  end

  it 'saves sha' do
    service.execute
    evidence = Releases::Evidence.last

    expect(evidence.summary_sha).not_to be_nil
  end

  context 'when the release has associated packages' do
    let_it_be_with_reload(:release) { create(:release, project: project, tag: 'v1.0.0') }
    let_it_be(:package) { create(:generic_package, project: project, version: '1.0.0') }

    it 'includes packages in the evidence summary' do
      service.execute
      evidence = Releases::Evidence.last

      packages = evidence.summary["release"]["packages"]
      expect(packages).to contain_exactly(
        a_hash_including("name" => package.name, "version" => "1.0.0")
      )
    end
  end

  context 'when the release has no associated packages' do
    it 'includes an empty packages array in the evidence summary' do
      service.execute
      evidence = Releases::Evidence.last

      expect(evidence.summary["release"]["packages"]).to eq([])
    end
  end

  context 'with milestone issues' do
    let_it_be(:milestone) { create(:milestone, project: project) }
    let_it_be(:issues) { create_list(:issue, 2, project: project, milestone: milestone, description: 'x' * 5_000) }

    let(:release) { create(:release, project: project, milestones: [milestone]) }
    let(:served_bytes) { Releases::EvidenceSizeLimit.new(release).served_bytes }

    def stored_issues
      service.execute

      Releases::Evidence.last.read_attribute(:summary).dig('release', 'milestones', 0, 'issues')
    end

    before do
      stub_application_setting(release_evidence_max_size_bytes: served_bytes + extra_bytes)
    end

    context 'when the issues fit within the limit' do
      let(:extra_bytes) { 20_000 }

      it 'stores every issue with its description' do
        expect(stored_issues).to match_array(
          issues.map { |issue| a_hash_including('id' => issue.id, 'description' => issue.description) }
        )
      end

      it 'reads the issues across batches' do
        stub_const("Releases::EvidenceSizeLimit::ISSUE_BATCH_SIZE", 1)

        expect(stored_issues).to match_array(
          issues.map { |issue| a_hash_including('id' => issue.id, 'description' => issue.description) }
        )
      end
    end

    context 'when the issue descriptions exceed the bytes the served parts leave' do
      # Room for both issues without descriptions and one description
      let(:extra_bytes) { 6_000 }

      it 'drops the descriptions that do not fit' do
        expect(stored_issues).to match([
          a_hash_including('id' => issues.first.id, 'description' => issues.first.description),
          a_hash_including('id' => issues.second.id, 'description' => nil)
        ])
      end

      it 'stores an evidence within the limit' do
        service.execute

        stored_bytes = Releases::Evidence.id_in(Releases::Evidence.last.id).pick(Arel.sql('OCTET_LENGTH(summary::text)'))
        expect(stored_bytes).to be <= served_bytes + extra_bytes
      end
    end

    context 'when no issue fits within the limit' do
      let(:extra_bytes) { 1 }

      it 'stores the evidence without issues' do
        expect(stored_issues).to eq([])
      end
    end

    context 'when the limit is 0' do
      let(:extra_bytes) { 1 }

      before do
        stub_application_setting(release_evidence_max_size_bytes: 0)
      end

      it 'stores every issue with its description' do
        expect(stored_issues).to all(include('description' => 'x' * 5_000))
        expect(stored_issues.size).to eq(2)
      end
    end

    context 'when the release_evidence_size_limit feature flag is disabled' do
      let(:extra_bytes) { 1 }

      before do
        stub_feature_flags(release_evidence_size_limit: false)
      end

      it 'stores every issue with its description' do
        expect(stored_issues).to all(include('description' => 'x' * 5_000))
        expect(stored_issues.size).to eq(2)
      end
    end
  end
end
