# frozen_string_literal: true

RSpec.shared_examples 'a deployable job policy' do |factory_type|
  subject(:policy) { described_class.new(user, job) }

  let_it_be_with_refind(:project) { create(:project, :private) }
  let_it_be_with_refind(:user) { create(:user) }

  let(:job) { create(factory_type, project: project, user: user, environment: 'production', ref: 'development') }

  context 'when the job triggerer is a project maintainer' do
    before_all do
      project.add_maintainer(user)
    end

    it { expect_allowed(:update_build, :retry_job, :play_job, :unschedule_job, :keep_job_artifacts) }

    context 'when job is oudated deployment job' do
      before do
        allow(job).to receive(:has_outdated_deployment?).and_return(true)
      end

      it 'denies the job permissions' do
        expect_disallowed(:update_build, :retry_job, :play_job, :unschedule_job, :keep_job_artifacts, :cancel_build)
      end
    end
  end
end
