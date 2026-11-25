# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Releases::EvidenceSizeLimit, feature_category: :release_evidence do
  let_it_be_with_reload(:project) { create(:project, name: 'Project', description: 'Project description') }
  let_it_be(:release) do
    create(:release, project: project, tag: 'v1.0.0', name: 'v1.0.0', description: 'b' * 2_000,
      milestones: [create(:milestone, project: project, title: 'v1.0', description: 'a' * 1_000)])
  end

  let_it_be(:package) { create(:generic_package, project: project, name: 'my-package', version: '1.0.0') }

  let(:limit_bytes) { 10_000 }

  subject(:size_limit) { described_class.new(release) }

  before do
    stub_application_setting(release_evidence_max_size_bytes: limit_bytes)
  end

  describe '#served_bytes' do
    it 'sums the JSON size of the served text and an overhead per record' do
      # Each text is a JSON string, so it adds two bytes for its quotes
      release_text = 'v1.0.0'.bytesize + 2_000 + 'v1.0.0'.bytesize + (3 * 2)
      project_text = 'Project'.bytesize + 'Project description'.bytesize + (2 * 2)
      milestone_text = 'v1.0'.bytesize + 1_000 + (2 * 2)
      package_text = 'my-package'.bytesize + '1.0.0'.bytesize + (2 * 2)

      expect(size_limit.served_bytes).to eq(
        release_text + project_text + milestone_text + package_text + (4 * described_class::RECORD_OVERHEAD_BYTES)
      )
    end

    it 'counts multibyte characters by their bytes, without JSON escapes' do
      plain = create(:release, project: project, tag: 'v2.0.0', name: 'v2.0.0', description: nil)
      escaped = create(:release, project: project, tag: 'v2.0.1', name: 'v2.0.0', description: "\u00e9\"\n")

      # Two bytes for the accented letter, one each for the quote and newline, two for the JSON quotes
      expect(described_class.new(escaped).served_bytes - described_class.new(plain).served_bytes).to eq(6)
    end

    context 'when more packages match than fit in the limit on their overhead alone' do
      # Two packages fit on overhead, so the third already exceeds the limit
      let(:limit_bytes) { 2 * described_class::RECORD_OVERHEAD_BYTES }

      before_all do
        create_list(:generic_package, 3, project: project, version: '1.0.0')
      end

      it 'reads only one package past that number' do
        expect { size_limit.served_bytes }.to make_queries_matching(/FROM \(SELECT .+ LIMIT 3\) packages_packages/, 1)
      end
    end
  end

  describe '#exceeded?' do
    context 'when the served parts exceed the limit' do
      let(:limit_bytes) { 3_000 }

      it { is_expected.to be_exceeded }

      context 'when the limit is 0' do
        let(:limit_bytes) { 0 }

        it { is_expected.not_to be_exceeded }
      end

      context 'when the release_evidence_size_limit feature flag is disabled' do
        before do
          stub_feature_flags(release_evidence_size_limit: false)
        end

        it { is_expected.not_to be_exceeded }
      end
    end

    context 'when the served parts are within the limit' do
      it { is_expected.not_to be_exceeded }
    end
  end

  describe '#remaining_bytes' do
    it 'returns the bytes the served parts leave' do
      expect(size_limit.remaining_bytes).to eq(limit_bytes - size_limit.served_bytes)
    end

    context 'when the served parts exceed the limit' do
      let(:limit_bytes) { 3_000 }

      it 'returns 0' do
        expect(size_limit.remaining_bytes).to eq(0)
      end
    end
  end

  describe '#error_message' do
    it 'names the limit and asks for an administrator' do
      expect(size_limit.error_message).to eq(
        'The release evidence would exceed the maximum size of 9.77 KiB set for this instance. ' \
          'Ask an administrator to increase the release evidence size limit.'
      )
    end
  end

  describe '#upcoming_release_warning_message' do
    it 'says no evidence is collected on the release date and how to collect it' do
      expect(size_limit.upcoming_release_warning_message)
        .to start_with('Evidence will not be collected on the release date')
      expect(size_limit.upcoming_release_warning_message).to include(size_limit.error_message)
    end
  end

  describe '#warning_message' do
    it 'says no evidence was collected and how to collect it' do
      expect(size_limit.warning_message).to start_with('No evidence was collected for this release.')
      expect(size_limit.warning_message).to include(size_limit.error_message)
      expect(size_limit.warning_message).to end_with('collect the evidence with the release evidence API.')
    end
  end
end
