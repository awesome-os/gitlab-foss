# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Authn::DataRetention::OauthAccessTokenArchiveWorker, feature_category: :system_access do
  describe '#perform' do
    subject(:worker) { described_class.new }

    let(:cutoff_date) { OauthAccessToken::RETENTION_PERIOD.ago.beginning_of_day }

    let_it_be_with_reload(:very_old_revoked_token) do
      create(:oauth_access_token, created_at: 3.years.ago, revoked_at: 2.years.ago)
    end

    let_it_be_with_reload(:old_revoked_token) do
      create(:oauth_access_token, created_at: 3.months.ago, revoked_at: 2.months.ago)
    end

    let_it_be_with_reload(:old_revoked_token_after_cutoff) do
      create(:oauth_access_token,
        created_at: 1.month.ago.beginning_of_day + 1.hour, revoked_at: 1.week.ago)
    end

    let_it_be_with_reload(:recent_revoked_token) do
      create(:oauth_access_token, created_at: 2.weeks.ago, revoked_at: 1.week.ago)
    end

    let_it_be_with_reload(:active_token) do
      create(:oauth_access_token, revoked_at: nil)
    end

    before do
      stub_application_setting(authn_data_retention_cleanup_enabled: true)
    end

    it_behaves_like 'an idempotent worker' do
      # Sidekiq runs inline here, so the drain calls IAM.
      before do
        allow(Authn::IamAuthService).to receive(:enabled?).and_return(true)
        allow(Authn::IamService::GrpcClient).to receive(:new)
          .and_return(instance_double(Authn::IamService::GrpcClient, bulk_delete_oauth_refresh_tokens: nil))
      end
    end

    context 'when application setting is disabled' do
      before do
        stub_application_setting(authn_data_retention_cleanup_enabled: false)
      end

      it 'does not delete any tokens' do
        expect { worker.perform }.not_to change { OauthAccessToken.count }
        expect(OauthAccessToken.count).to eq(5)
      end

      it 'does not enqueue another job' do
        expect(described_class).not_to receive(:perform_in)
        worker.perform
      end
    end

    context 'when there are revoked tokens to delete', :freeze_time do
      context 'when there are revoked tokens to delete' do
        it 'deletes only revoked tokens created before cutoff date' do
          expect { worker.perform }.to change { OauthAccessToken.count }.by(-2)

          expect(OauthAccessToken.pluck(:id))
            .to contain_exactly(old_revoked_token_after_cutoff.id, recent_revoked_token.id, active_token.id)
        end

        it 'deletes tokens exactly at cutoff boundary' do
          token_at_boundary = create(:oauth_access_token, revoked_at: cutoff_date, created_at: cutoff_date - 1.month)

          expect { worker.perform }.to change { OauthAccessToken.exists?(token_at_boundary.id) }.from(true).to(false)
        end

        it 'logs the sub batch deletion count' do
          expect(Gitlab::AppLogger).to receive(:info).with(
            class: described_class.name,
            message: "Deleted OAuth tokens sub-batch",
            sub_batch_deleted: 2,
            cutoff_date: cutoff_date
          )

          worker.perform
        end

        it 'logs the total deleted count' do
          expect(worker)
            .to receive(:log_extra_metadata_on_done)
                  .with(:result, hash_including(
                    over_time: false,
                    total_deleted: 2,
                    cutoff_date: cutoff_date
                  ))

          worker.perform
        end

        context 'when the iam_data_replication feature flag is enabled' do
          let(:delete_rows) { Authn::IamOutbox.where(entity_type: 'oauth_access_token', event_type: :delete) }

          let!(:old_token_without_refresh_token) do
            create(:oauth_access_token, created_at: 3.months.ago, revoked_at: 2.months.ago, refresh_token: nil)
          end

          def delete_payload(token_id)
            { 'owning_cell_id' => Gitlab.config.cell.id.to_i, 'source_id' => token_id }
          end

          it 'records a delete row only for deleted tokens with a refresh token', :aggregate_failures do
            deleted_ids = [very_old_revoked_token.id, old_revoked_token.id]

            worker.perform

            expect(delete_rows.map { |row| [row.entity_id, row.payload] })
              .to match_array(deleted_ids.map { |id| [id, delete_payload(id)] })
            expect(OauthAccessToken.exists?(old_token_without_refresh_token.id)).to be(false)
          end

          it 'schedules a delete drain per recorded token after commit' do
            drain_args = [very_old_revoked_token, old_revoked_token].map { |t| ['oauth_access_token', t.id, 'delete'] }

            expect(Authn::IamReplication::DrainWorker).to receive(:bulk_perform_in)
              .with(Authn::IamReplication::DrainWorker::SCHEDULE_DELAY, match_array(drain_args))

            worker.perform
          end

          it 'sends the ids of the deleted tokens to IAM', :sidekiq_inline do
            client = instance_double(Authn::IamService::GrpcClient)
            allow(Authn::IamAuthService).to receive(:enabled?).and_return(true)
            allow(Authn::IamService::GrpcClient).to receive(:new).and_return(client)
            cell_id = Gitlab.config.cell.id.to_i

            expect(client).to receive(:bulk_delete_oauth_refresh_tokens)
              .with(token_ids: [{ owning_cell_id: cell_id, source_id: very_old_revoked_token.id }])
            expect(client).to receive(:bulk_delete_oauth_refresh_tokens)
              .with(token_ids: [{ owning_cell_id: cell_id, source_id: old_revoked_token.id }])

            worker.perform
          end
        end

        context 'when the iam_data_replication feature flag is disabled' do
          before do
            stub_feature_flags(iam_data_replication: false)
          end

          it 'still deletes the old revoked tokens and records no row', :aggregate_failures do
            expect { worker.perform }.not_to change { Authn::IamOutbox.count }

            expect(OauthAccessToken.pluck(:id))
              .to contain_exactly(old_revoked_token_after_cutoff.id, recent_revoked_token.id, active_token.id)
          end
        end

        context 'with large batch processing' do
          before do
            stub_const("#{described_class}::BATCH_SIZE", 10)
            stub_const("#{described_class}::SUB_BATCH_SIZE", 5)

            create_list(:oauth_access_token, 6,
              revoked_at: 2.months.ago,
              created_at: 3.months.ago)
          end

          it 'processes tokens in batches', :aggregate_failures do
            deleted_ids = OauthAccessToken.where(revoked_at: ..cutoff_date).ids

            expect(worker).to receive(:log_sub_batch_deleted)
                                .at_least(3).times
                                .and_call_original

            worker.perform

            expect(OauthAccessToken.where(created_at: ..cutoff_date).count).to eq(0)
            expect(Authn::IamOutbox.where(entity_type: 'oauth_access_token', event_type: :delete).pluck(:entity_id))
              .to match_array(deleted_ids)
          end
        end

        context 'when the runtime limit is reached' do
          before do
            stub_const("#{described_class}::BATCH_SIZE", 4)
            stub_const("#{described_class}::SUB_BATCH_SIZE", 2)

            allow_next_instance_of(Gitlab::Metrics::RuntimeLimiter) do |runtime_limiter|
              allow(runtime_limiter).to receive_messages(over_time?: true, was_over_time?: true)
            end

            create(:oauth_access_token, created_at: 1.year.ago, revoked_at: 10.months.ago)
          end

          it 'reschedules the worker' do
            expect(described_class).to receive(:perform_in).with(3.minutes, an_instance_of(Integer))
            worker.perform
          end

          it 'stops processing when limit reached' do
            worker.perform

            remaining = OauthAccessToken.where(revoked_at: ..cutoff_date).count
            expect(remaining).to be 1
          end

          it 'exposes the correct traceability metrics' do
            expect(worker)
              .to receive(:log_extra_metadata_on_done)
                    .with(:result, hash_including(
                      over_time: true,
                      total_deleted: 2
                    ))

            worker.perform
          end
        end

        context 'when there is a database error' do
          before do
            # rubocop:disable RSpec/AnyInstanceOf -- each_batch creates multiple Relation instances that need stubbing
            allow_any_instance_of(ActiveRecord::Relation)
              .to receive(:delete_all)
                    .and_raise(ActiveRecord::StatementInvalid.new('Failed to execute'))
            # rubocop:enable RSpec/AnyInstanceOf
          end

          it 'skip logs and raises the error' do
            expect(Gitlab::AppLogger).not_to receive(:info)

            expect { worker.perform }.to raise_error(ActiveRecord::StatementInvalid, 'Failed to execute')
          end

          it 'does not partially delete tokens' do
            expect { worker.perform }.to raise_error(ActiveRecord::StatementInvalid)

            expect(OauthAccessToken.count).to eq(5)
          end

          it 'rolls back the delete rows written before the failed delete', :aggregate_failures do
            allow(Authn::IamOutbox).to receive(:insert_all!).and_call_original

            expect { worker.perform }
              .to raise_error(ActiveRecord::StatementInvalid)
              .and not_change { Authn::IamOutbox.count }
            expect(Authn::IamOutbox).to have_received(:insert_all!).once
          end
        end
      end

      context 'when there are no tokens to delete' do
        before do
          OauthAccessToken.update_all(revoked_at: 1.week.ago)
        end

        it 'does not delete any tokens' do
          expect { worker.perform }.not_to change { OauthAccessToken.count }
        end

        it 'does not enqueue another job' do
          expect(described_class).not_to receive(:perform_in)
          worker.perform
        end

        it 'logs zero deleted count' do
          expect(worker).to receive(:log_extra_metadata_on_done).with(:result, hash_including(total_deleted: 0))

          worker.perform
        end
      end

      context 'when all tokens are active' do
        before do
          OauthAccessToken.update_all(revoked_at: nil)
        end

        it 'does not process any tokens' do
          expect { worker.perform }.not_to change { OauthAccessToken.count }
        end
      end
    end
  end
end
