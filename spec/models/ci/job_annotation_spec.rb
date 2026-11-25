# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ci::JobAnnotation, feature_category: :job_artifacts do
  let_it_be_with_refind(:job) { create(:ci_build, :success) }

  describe 'validations' do
    let!(:annotations) { create(:ci_job_annotation, job: job) }

    it 'belongs to a job through composite keys' do
      is_expected.to belong_to(:job).class_name('Ci::Build').inverse_of(:job_annotations)
        .with_query_constraints([:job_id, :partition_id]).with_primary_key([:id, :partition_id])
    end

    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_length_of(:name).is_at_most(255) }
    it { is_expected.to validate_presence_of(:project_id) }
  end

  describe '.create' do
    context 'when JSON data is valid' do
      subject do
        job.job_annotations.create!(
          name: 'external',
          data: [{ external_link: { label: 'Example', url: 'https://example.com/' } }]
        )
      end

      it 'creates the object' do
        expect(subject).to be_a(described_class)
        expect(subject.data).to contain_exactly(a_hash_including('external_link' =>
          a_hash_including('label' => 'Example', 'url' => 'https://example.com/')))
      end
    end

    context 'when JSON data is invalid' do
      subject { job.job_annotations.create!(name: 'external', data: [{ invalid: 'invalid' }]) }

      it 'throws an error' do
        expect { subject }.to raise_error(ActiveRecord::RecordInvalid)
      end
    end

    context 'when there are more than 1000 JSON entries' do
      subject { job.job_annotations.create!(data: [{ external_link: { label: 'Example', url: 'https://example.com/' } }] * 1001) }

      it 'throws an error' do
        expect { subject }.to raise_error(ActiveRecord::RecordInvalid)
      end
    end
  end
end
