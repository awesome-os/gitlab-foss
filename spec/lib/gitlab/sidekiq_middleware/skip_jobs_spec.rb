# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::SidekiqMiddleware::SkipJobs, feature_category: :scalability do
  let(:job) { { 'jid' => 123, 'args' => [456] } }
  let(:queue) { 'test_queue' }
  let(:setter) { instance_double(Sidekiq::Job::Setter) }
  let(:worker) do
    Class.new do
      def self.name
        'TestWorker'
      end
      include ApplicationWorker

      feature_category :scalability
    end
  end

  subject { described_class.new }

  before do
    stub_const('TestWorker', worker)
    stub_feature_flags("drop_sidekiq_jobs_#{TestWorker.name}": false)
  end

  describe '#call' do
    context 'with worker not opted for database health check' do
      let(:metric) { instance_double(Prometheus::Client::Counter, increment: true) }
      let(:worker_instance) { TestWorker.new }
      let(:metric_worker) { 'TestWorker' }
      let(:metric_feature_category) { 'scalability' }

      shared_examples 'runs the job normally' do
        it 'yields control' do
          expect { |b| subject.call(worker_instance, job, queue, &b) }.to yield_control
        end

        it 'does not increment any metric counter' do
          expect(metric).not_to receive(:increment)

          subject.call(worker_instance, job, queue) { nil }
        end

        it 'does not increment deferred_count' do
          subject.call(worker_instance, job, queue) { nil }

          expect(job).not_to include('deferred_count')
        end

        context 'when deferred jobs are re-enabled' do
          let(:job) { super().merge('deferred' => true) }

          it 'does not have the deferred key in job hash' do
            subject.call(worker_instance, job, queue) { nil }

            expect(job).not_to include('deferred')
          end
        end
      end

      shared_examples 'drops the job' do
        it 'does not yield control' do
          expect { |b| subject.call(worker_instance, job, queue, &b) }.not_to yield_control
        end

        it 'increments counter' do
          expect(metric).to receive(:increment).with({
            worker: metric_worker,
            action: "dropped",
            reason: "feature_flag",
            feature_category: metric_feature_category
          })

          subject.call(worker_instance, job, queue) { nil }
        end

        it 'does not increment deferred_count' do
          subject.call(worker_instance, job, queue) { nil }

          expect(job).not_to include('deferred_count')
        end

        it 'has dropped field in job equal to true' do
          subject.call(worker_instance, job, queue) { nil }

          expect(job).to include({ 'dropped' => true })
        end
      end

      shared_examples 'defers the job' do
        it 'does not yield control' do
          expect { |b| subject.call(TestWorker.new, job, queue, &b) }.not_to yield_control
        end

        it 'delays the job' do
          expect(TestWorker).to receive(:set)
            .with(deferred: true, deferred_count: 1, deferred_by: :feature_flag)
            .and_return(setter)
          expect(setter).to receive(:set).with(jid: job['jid']).and_return(setter)
          expect(setter).to receive(:perform_in).with(described_class::DELAY, *job['args'])

          subject.call(TestWorker.new, job, queue) { nil }
        end

        it 'increments counter' do
          expect(metric).to receive(:increment).with({
            worker: "TestWorker",
            action: "deferred",
            reason: "feature_flag",
            feature_category: "scalability"
          })

          subject.call(TestWorker.new, job, queue) { nil }
        end

        it 'has deferred related fields in job payload' do
          subject.call(TestWorker.new, job, queue) { nil }

          expect(job).to include({ 'deferred' => true, 'deferred_by' => :feature_flag, 'deferred_count' => 1 })
          expect(job).not_to have_key('deferred_mailer')
        end

        it 'keeps the place of the job in its call chain' do
          job.merge!('meta.root_started_at' => 1234.5, 'meta.correlation_depth' => 3)

          expect(TestWorker).to receive(:set).with(hash_including(deferred: true)).and_return(setter)
          expect(setter).to receive(:set)
            .with(hash_including(jid: job['jid'], 'meta.root_started_at' => 1234.5, 'meta.correlation_depth' => 3))
            .and_return(setter)
          expect(setter).to receive(:perform_in)

          subject.call(TestWorker.new, job, queue) { nil }
        end

        it 'keeps the WAL locations the job was queued with' do
          wal_keys = {
            'wal_locations' => { 'main' => '0/D525E3A8' },
            'wal_location_sources' => { 'main' => 'primary' },
            'dedup_wal_locations' => { 'main' => '0/D525E3B0' }
          }
          job.merge!(wal_keys)

          expect(TestWorker).to receive(:set).with(hash_including(deferred: true)).and_return(setter)
          expect(setter).to receive(:set).with(hash_including({ jid: job['jid'] }.merge(wal_keys))).and_return(setter)
          expect(setter).to receive(:perform_in)

          subject.call(TestWorker.new, job, queue) { nil }
        end
      end

      describe "with all combinations of drop and defer FFs" do
        using RSpec::Parameterized::TableSyntax

        before do
          stub_feature_flags("drop_sidekiq_jobs_#{TestWorker.name}": drop_ff)
          stub_feature_flags("run_sidekiq_jobs_#{TestWorker.name}": run_ff)
          allow(Gitlab::Metrics).to receive(:counter).and_call_original
          allow(Gitlab::Metrics).to receive(:counter).with(described_class::COUNTER, anything).and_return(metric)
        end

        where(:drop_ff, :run_ff, :resulting_behavior) do
          false | true  | "runs the job normally"
          true  | true  | "drops the job"
          false | false | "defers the job"
          true  | false | "drops the job"
        end

        with_them do
          it_behaves_like params[:resulting_behavior]
        end
      end

      context 'when a deferred job uses load balancing', :database_replica do
        before do
          stub_feature_flags("run_sidekiq_jobs_#{TestWorker.name}": false)
          allow(Gitlab::Metrics).to receive(:counter).and_call_original
          allow(Gitlab::Metrics).to receive(:counter).with(described_class::COUNTER, anything).and_return(metric)
          TestWorker.data_consistency :sticky
        end

        it 'requeues it with the WAL locations it was queued with, not a replica location' do
          wal_keys = {
            'wal_locations' => { 'main' => '0/D525E3A8' },
            'wal_location_sources' => { 'main' => 'primary' }
          }
          job.merge!(wal_keys)

          Sidekiq::Testing.fake! { subject.call(TestWorker.new, job, queue) { nil } }

          expect(TestWorker.jobs.last).to include(wal_keys)
        end
      end

      context 'with an ActiveJob job' do
        let(:job_wrapper) { ActiveJob::QueueAdapters::SidekiqAdapter::JobWrapper }
        let(:worker_instance) { job_wrapper.new }
        let(:mail_job) { ActionMailer::MailDeliveryJob.new('Notify', 'test_email', 'deliver_now', args: [1]) }
        let(:queue) { 'mailers' }
        let(:job) do
          {
            'class' => job_wrapper.name,
            'wrapped' => mail_job.class.name,
            'queue' => queue,
            'retry' => 3,
            'jid' => 'abc123',
            'args' => [mail_job.serialize]
          }
        end

        let(:metric_worker) { 'ActionMailer::MailDeliveryJob' }
        let(:metric_feature_category) { ActionMailer::MailDeliveryJob.get_feature_category.to_s }

        before do
          stub_feature_flags(
            'drop_sidekiq_jobs_ActionMailer::MailDeliveryJob': drop_ff,
            'run_sidekiq_jobs_ActionMailer::MailDeliveryJob': run_ff
          )
          allow(Gitlab::Metrics).to receive(:counter).and_call_original
          allow(Gitlab::Metrics).to receive(:counter).with(described_class::COUNTER, anything).and_return(metric)
        end

        context 'with no flags set' do
          let(:drop_ff) { false }
          let(:run_ff) { true }

          it_behaves_like 'runs the job normally'
        end

        context 'with drop_sidekiq_jobs enabled' do
          let(:drop_ff) { true }
          let(:run_ff) { true }

          it_behaves_like 'drops the job'
        end

        context 'with run_sidekiq_jobs disabled' do
          let(:drop_ff) { false }
          let(:run_ff) { false }

          it 'does not yield control' do
            expect { |b| subject.call(worker_instance, job, queue, &b) }.not_to yield_control
          end

          it 're-enqueues the job through the wrapper with the wrapped class, queue, retry and args' do
            Sidekiq::Testing.fake! { subject.call(worker_instance, job, queue) { nil } }

            expect(job_wrapper.jobs.last).to include(
              'wrapped' => 'ActionMailer::MailDeliveryJob',
              'queue' => queue,
              'retry' => 3,
              'jid' => job['jid'],
              'args' => job['args'],
              'deferred' => true,
              'deferred_count' => 1,
              'deferred_by' => 'feature_flag'
            )
          end

          it 'defers the re-enqueued job again when it comes back' do
            Sidekiq::Testing.fake! do
              subject.call(worker_instance, job, queue) { nil }

              expect { |b| subject.call(worker_instance, job_wrapper.jobs.last, queue, &b) }.not_to yield_control
            end

            expect(job_wrapper.jobs.last)
              .to include('wrapped' => 'ActionMailer::MailDeliveryJob', 'deferred_count' => 2)
          end

          it 'records the mailer and method on the job for the logs' do
            Sidekiq::Testing.fake! { subject.call(worker_instance, job, queue) { nil } }

            expect(job['deferred_mailer']).to eq('Notify:test_email')
          end

          it 'defers a malformed mail payload without recording a mailer' do
            job['args'] = ['not a hash']

            Sidekiq::Testing.fake! { subject.call(worker_instance, job, queue) { nil } }

            expect(job).to include('deferred' => true, 'deferred_mailer' => nil)
          end

          it 'increments counter' do
            expect(metric).to receive(:increment).with({
              worker: metric_worker,
              action: "deferred",
              reason: "feature_flag",
              feature_category: metric_feature_category
            })

            Sidekiq::Testing.fake! { subject.call(worker_instance, job, queue) { nil } }
          end
        end

        context 'when pausing a single mailer' do
          let(:drop_ff) { false }
          let(:run_ff) { true }

          shared_examples 'defers the mail job' do
            it 'does not yield control' do
              expect { |b| subject.call(worker_instance, job, queue, &b) }.not_to yield_control
            end

            it 're-enqueues the mail job with the wrapped class, queue, retry and args' do
              Sidekiq::Testing.fake! { subject.call(worker_instance, job, queue) { nil } }

              expect(job_wrapper.jobs.last).to include(
                'wrapped' => 'ActionMailer::MailDeliveryJob',
                'queue' => queue,
                'retry' => 3,
                'args' => job['args'],
                'deferred' => true,
                'deferred_by' => 'feature_flag'
              )
            end

            it 'counts it against the mail job class' do
              expect(metric).to receive(:increment).with(hash_including(worker: metric_worker, action: 'deferred'))

              Sidekiq::Testing.fake! { subject.call(worker_instance, job, queue) { nil } }
            end

            it 'records the mailer and method on the job for the logs' do
              Sidekiq::Testing.fake! { subject.call(worker_instance, job, queue) { nil } }

              expect(job['deferred_mailer']).to eq('Notify:test_email')
            end
          end

          context 'with the mailer paused' do
            before do
              stub_feature_flags(run_sidekiq_jobs_Notify: false)
            end

            it_behaves_like 'defers the mail job'
          end

          context 'with the mailer method paused' do
            before do
              stub_feature_flags('run_sidekiq_jobs_Notify:test_email': false)
            end

            it_behaves_like 'defers the mail job'
          end

          context 'with another method of the mailer paused' do
            before do
              stub_feature_flags('run_sidekiq_jobs_Notify:other_email': false)
            end

            it_behaves_like 'runs the job normally'
          end

          context 'with another mailer paused' do
            before do
              stub_feature_flags(run_sidekiq_jobs_Other: false, 'run_sidekiq_jobs_Other:test_email': false)
            end

            it_behaves_like 'runs the job normally'
          end

          context 'with the mailer paused and drop_sidekiq_jobs enabled for mail jobs' do
            let(:drop_ff) { true }

            before do
              stub_feature_flags(run_sidekiq_jobs_Notify: false)
            end

            it_behaves_like 'drops the job'
          end

          context 'with the mailer flag explicitly enabled' do
            before do
              stub_feature_flags(run_sidekiq_jobs_Notify: true)
            end

            it_behaves_like 'runs the job normally'
          end

          context 'with a malformed mail payload' do
            using RSpec::Parameterized::TableSyntax

            where(:args) do
              [
                [nil],
                [['unexpected']],
                [[{ 'job_class' => 'ActionMailer::MailDeliveryJob' }]],
                [[{ 'arguments' => [123, 'test_email'] }]],
                [[{ 'arguments' => ['Notify'] }]]
              ]
            end

            with_them do
              before do
                stub_feature_flags(run_sidekiq_jobs_Notify: false)
                job['args'] = args
              end

              it_behaves_like 'runs the job normally'
            end
          end

          context 'with a non-mail ActiveJob job carrying the same arguments' do
            let(:other_job_class) { Class.new(ActiveJob::Base) } # rubocop:disable Rails/ApplicationJob -- no ApplicationJob exists

            before do
              stub_const('OtherActiveJob', other_job_class)
              stub_feature_flags(
                drop_sidekiq_jobs_OtherActiveJob: false,
                run_sidekiq_jobs_OtherActiveJob: true,
                run_sidekiq_jobs_Notify: false
              )
              job['wrapped'] = 'OtherActiveJob'
            end

            it 'is not paused by the mailer flag' do
              expect { |b| subject.call(worker_instance, job, queue, &b) }.to yield_control
            end
          end

          describe 'flag lookups per job' do
            let(:looked_up) { [] }

            before do
              allow(Feature).to receive(:enabled?).and_wrap_original do |original, key, *args, **kwargs|
                looked_up << key.to_s if key.to_s.match?(/\A(run|drop)_sidekiq_jobs_/)
                original.call(key, *args, **kwargs)
              end
            end

            it 'checks the drop, class, mailer and method flags for a mail job when nothing is paused' do
              subject.call(worker_instance, job, queue) { nil }

              expect(looked_up).to eq(%w[
                drop_sidekiq_jobs_ActionMailer::MailDeliveryJob
                run_sidekiq_jobs_ActionMailer::MailDeliveryJob
                run_sidekiq_jobs_Notify
                run_sidekiq_jobs_Notify:test_email
              ])
            end

            it 'checks only the drop and run flags for any other job' do
              subject.call(TestWorker.new, { 'jid' => 1, 'args' => [1] }, 'test_queue') { nil }

              expect(looked_up).to eq(%w[drop_sidekiq_jobs_TestWorker run_sidekiq_jobs_TestWorker])
            end
          end
        end
      end

      describe 'using current_request actor', :request_store do
        before do
          allow(Gitlab::Metrics).to receive(:counter).and_call_original
          allow(Gitlab::Metrics).to receive(:counter).with(described_class::COUNTER, anything).and_return(metric)
        end

        context 'with drop_sidekiq_jobs FF' do
          before do
            stub_feature_flags("drop_sidekiq_jobs_#{TestWorker.name}": Feature.current_request)
          end

          it_behaves_like 'drops the job'

          context 'for different request' do
            before do
              stub_with_new_feature_current_request
            end

            it_behaves_like 'runs the job normally'
          end
        end

        context 'with run_sidekiq_jobs FF' do
          before do
            stub_feature_flags("run_sidekiq_jobs_#{TestWorker.name}": Feature.current_request)
          end

          it_behaves_like 'runs the job normally'

          context 'for different request' do
            before do
              stub_with_new_feature_current_request
            end

            it_behaves_like 'defers the job'
          end
        end
      end
    end

    context 'with worker opted for database health check' do
      let(:health_signal_attrs) { { gitlab_schema: :gitlab_main, tables: [:users], delay_by: 1.minute } }

      around do |example|
        with_sidekiq_server_middleware do |chain|
          chain.add described_class
          Sidekiq::Testing.inline! { example.run }
        end
      end

      before do
        TestWorker.defer_on_database_health_signal(*health_signal_attrs.values)
      end

      context 'without any stop signal from database health check' do
        it 'runs the job normally' do
          expect { |b| subject.call(TestWorker.new, job, queue, &b) }.to yield_control
        end

        it 'evaluates the default indicators' do
          expect(Gitlab::Database::HealthStatus).to receive(:evaluate)
            .with(anything, Gitlab::Database::HealthStatus::DEFAULT_INDICATORS).and_call_original

          subject.call(TestWorker.new, job, queue) { nil }
        end
      end

      context 'when indicators are provided' do
        before do
          TestWorker.defer_on_database_health_signal(
            *health_signal_attrs.values, indicators: Gitlab::Database::HealthStatus::GLOBAL_INDICATORS
          )
        end

        it 'evaluates only the given indicators' do
          expect(Gitlab::Database::HealthStatus).to receive(:evaluate)
            .with(anything, Gitlab::Database::HealthStatus::GLOBAL_INDICATORS).and_call_original

          expect { |b| subject.call(TestWorker.new, job, queue, &b) }.to yield_control
        end
      end

      context 'with stop signal from database health check' do
        let(:metric) { instance_double(Prometheus::Client::Counter, increment: true) }

        before do
          stop_signal = instance_double(Gitlab::Database::HealthStatus::Signals::Stop, stop?: true)
          allow(Gitlab::Database::HealthStatus).to receive(:evaluate).and_return([stop_signal])
          allow(Gitlab::Metrics).to receive(:counter).and_call_original
          allow(Gitlab::Metrics).to receive(:counter).with(described_class::COUNTER, anything).and_return(metric)
        end

        it 'defers the job by set time' do
          expect(TestWorker).to receive(:set)
            .with(deferred: true, deferred_count: 1, deferred_by: :database_health_check)
            .and_return(setter)
          expect(setter).to receive(:set).with(hash_including(jid: anything)).and_return(setter)
          expect(setter).to receive(:perform_in).with(health_signal_attrs[:delay_by], *job['args'])

          TestWorker.perform_async(*job['args'])
        end

        it 'increments counter' do
          expect(TestWorker).to receive(:set)
            .with(deferred: true, deferred_count: 1, deferred_by: :database_health_check)
            .and_return(setter)
          expect(setter).to receive(:set).with(hash_including(jid: anything)).and_return(setter)
          expect(setter).to receive(:perform_in).with(health_signal_attrs[:delay_by], *job['args'])
          expect(metric).to receive(:increment).with({
            worker: "TestWorker",
            action: "deferred",
            reason: "database_health_check",
            feature_category: "scalability"
          })

          TestWorker.perform_async(*job['args'])
        end

        context 'when the job has already been deferred by the database health check' do
          using RSpec::Parameterized::TableSyntax

          let(:job) { { 'jid' => 123, 'args' => [456], 'deferred_count' => deferred_count } }

          before do
            allow(subject).to receive(:rand).and_return(0)
          end

          # delay_by is 1 minute, set by the health_signal_attrs fixture. deferred_count is the
          # pre-increment value from the job hash;
          # defer_job! increments it before computing the delay, so the first row is the job's
          # second deferral. Each consecutive deferral doubles the delay, capped at 30 minutes.
          where(:deferred_count, :expected_delay) do
            1  | 2.minutes.to_i
            2  | 4.minutes.to_i
            4  | 16.minutes.to_i
            5  | 30.minutes.to_i
            50 | 30.minutes.to_i
          end

          with_them do
            it 'defers the job with exponential backoff' do
              expect(TestWorker).to receive(:set)
                .with(deferred: true, deferred_count: deferred_count + 1, deferred_by: :database_health_check)
                .and_return(setter)
              expect(setter).to receive(:set).with(jid: job['jid']).and_return(setter)
              expect(setter).to receive(:perform_in).with(expected_delay, *job['args'])

              subject.call(TestWorker.new, job, queue) { nil }
            end
          end
        end

        context 'with jitter' do
          let(:job) { { 'jid' => 123, 'args' => [456], 'deferred_count' => 50 } }

          it 'subtracts up to 10% of the capped delay so the cap is a hard ceiling' do
            expect(subject).to receive(:rand).with((30.minutes.to_i / 10) + 1).and_return(42)

            expect(TestWorker).to receive(:set)
              .with(deferred: true, deferred_count: 51, deferred_by: :database_health_check)
              .and_return(setter)
            expect(setter).to receive(:set).with(jid: job['jid']).and_return(setter)
            expect(setter).to receive(:perform_in).with(30.minutes.to_i - 42, *job['args'])

            subject.call(TestWorker.new, job, queue) { nil }
          end
        end

        context 'when the job was previously deferred by the feature flag' do
          let(:job) do
            { 'jid' => 123, 'args' => [456], 'deferred_count' => 3, 'deferred_by' => 'feature_flag' }
          end

          it 'backs off from the shared deferred_count' do
            allow(subject).to receive(:rand).and_return(0)

            expect(TestWorker).to receive(:set)
              .with(deferred: true, deferred_count: 4, deferred_by: :database_health_check)
              .and_return(setter)
            expect(setter).to receive(:set).with(jid: job['jid']).and_return(setter)
            expect(setter).to receive(:perform_in).with(8.minutes.to_i, *job['args'])

            subject.call(TestWorker.new, job, queue) { nil }
          end
        end

        context 'when incremental_database_health_defer_delay is disabled' do
          let(:job) { { 'jid' => 123, 'args' => [456], 'deferred_count' => 5 } }

          before do
            stub_feature_flags(incremental_database_health_defer_delay: false)
          end

          it 'defers the job by the fixed delay_by' do
            expect(TestWorker).to receive(:set)
              .with(deferred: true, deferred_count: 6, deferred_by: :database_health_check)
              .and_return(setter)
            expect(setter).to receive(:set).with(jid: job['jid']).and_return(setter)
            expect(setter).to receive(:perform_in).with(health_signal_attrs[:delay_by], *job['args'])

            subject.call(TestWorker.new, job, queue) { nil }
          end
        end

        context 'when the job is deferred by the run_sidekiq_jobs feature flag' do
          let(:job) { { 'jid' => 123, 'args' => [456], 'deferred_count' => 3 } }

          before do
            stub_feature_flags("run_sidekiq_jobs_#{TestWorker.name}": false)
          end

          it 'uses the fixed delay regardless of deferred_count' do
            expect(TestWorker).to receive(:set)
              .with(deferred: true, deferred_count: 4, deferred_by: :feature_flag)
              .and_return(setter)
            expect(setter).to receive(:set).with(jid: job['jid']).and_return(setter)
            expect(setter).to receive(:perform_in).with(described_class::DELAY, *job['args'])

            subject.call(TestWorker.new, job, queue) { nil }
          end
        end
      end

      context 'when a block is provided' do
        before do
          TestWorker.defer_on_database_health_signal(*health_signal_attrs.values) do
            [:gitlab_ci, [:ci_pipelines]]
          end
        end

        it 'uses the lazy evaluated schema and tables returned by the block' do
          expect(Gitlab::Database::HealthStatus::Context).to receive(:new)
            .with(anything, anything, [:ci_pipelines]).and_call_original

          expect { |b| subject.call(TestWorker.new, job, queue, &b) }.to yield_control
        end
      end
    end
  end
end
