# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Authz::ScheduleReverifyProjectAuthorizationsWorker, feature_category: :permissions do
  let(:worker) { described_class.new }

  before do
    stub_feature_flags(do_not_run_safety_net_auth_refresh_jobs: false, authz_refresh_verifier: false)
  end

  it_behaves_like 'an idempotent worker'

  it 'has the `until_executing` deduplicate strategy' do
    expect(described_class.get_deduplicate_strategy).to eq(:until_executing)
  end

  describe '#perform' do
    subject(:perform) { worker.perform }

    context 'when a record is ready to be processed' do
      before_all do
        create(:project_authorization_reverification, :to_be_processed)
      end

      it 'schedules the reverification worker with capacity' do
        expect(Authz::ReverifyProjectAuthorizationsCronWorker).to receive(:perform_with_capacity)

        perform
      end
    end

    context 'when no record is ready to be processed' do
      before_all do
        create(:project_authorization_reverification)
      end

      it 'does not schedule the reverification worker' do
        expect(Authz::ReverifyProjectAuthorizationsCronWorker).not_to receive(:perform_with_capacity)

        perform
      end
    end

    context 'when a record was abandoned by a previous run' do
      let_it_be(:reverification) do
        create(:project_authorization_reverification, :abandoned, :to_be_processed)
      end

      it 'returns the record to pending and schedules the reverification worker' do
        expect(Authz::ReverifyProjectAuthorizationsCronWorker).to receive(:perform_with_capacity)

        expect { perform }.to change { reverification.reload.status }.from('processing').to('pending')
      end
    end

    context 'when a record is still being processed by another worker' do
      let_it_be(:reverification) { create(:project_authorization_reverification, :processing) }

      it 'neither requeues the record nor schedules the reverification worker' do
        expect(Authz::ReverifyProjectAuthorizationsCronWorker).not_to receive(:perform_with_capacity)

        expect { perform }.not_to change { reverification.reload.status }.from('processing')
      end
    end

    context 'when the feature flag `do_not_run_safety_net_auth_refresh_jobs` is enabled' do
      let_it_be(:reverification) do
        create(:project_authorization_reverification, :abandoned, :to_be_processed)
      end

      before do
        stub_feature_flags(do_not_run_safety_net_auth_refresh_jobs: true)
      end

      it 'neither requeues abandoned records nor schedules the reverification worker' do
        expect(Authz::ReverifyProjectAuthorizationsCronWorker).not_to receive(:perform_with_capacity)

        expect { perform }.not_to change { reverification.reload.status }.from('processing')
      end
    end
  end

  describe 'verifying a sample' do
    subject(:perform) { worker.perform }

    let(:verify_service) { instance_double(Authz::ProjectAuthorizations::VerifyService) }
    let(:payload) { { sampled: 3, matches: 2, drift: 1, complete: true } }

    before do
      stub_feature_flags(authz_refresh_verifier: true)
      allow(Authz::ProjectAuthorizations::VerifyService).to receive(:new).and_return(verify_service)
      allow(verify_service).to receive(:execute).and_return(ServiceResponse.success(payload: payload))
    end

    it 'verifies a sample after scheduling the reverification worker, and logs the outcomes' do
      create(:project_authorization_reverification, :to_be_processed)
      expect(Authz::ReverifyProjectAuthorizationsCronWorker).to receive(:perform_with_capacity).ordered
      expect(verify_service).to receive(:execute).ordered

      perform

      prefix = 'extra.authz_schedule_reverify_project_authorizations_worker'
      expect(worker.logging_extras).to include("#{prefix}.verifier_sampled" => 3, "#{prefix}.verifier_drift" => 1)
    end

    it 'verifies when no record is ready to be processed' do
      perform

      expect(verify_service).to have_received(:execute)
    end

    it 'verifies while the safety net is switched off' do
      stub_feature_flags(do_not_run_safety_net_auth_refresh_jobs: true)

      perform

      expect(verify_service).to have_received(:execute)
    end

    it 'tracks a failure without failing the job' do
      allow(verify_service).to receive(:execute).and_raise(ActiveRecord::QueryCanceled)

      expect(Gitlab::ErrorTracking).to receive(:track_exception).with(instance_of(ActiveRecord::QueryCanceled))

      expect { perform }.not_to raise_error
    end

    it 'does nothing while its flag is off' do
      stub_feature_flags(authz_refresh_verifier: false)

      perform

      expect(Authz::ProjectAuthorizations::VerifyService).not_to have_received(:new)
    end
  end
end
