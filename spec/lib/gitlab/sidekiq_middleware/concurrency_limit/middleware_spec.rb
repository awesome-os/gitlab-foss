# frozen_string_literal: true

require 'spec_helper'
require 'labkit/context'
require 'labkit/fields'

RSpec.describe Gitlab::SidekiqMiddleware::ConcurrencyLimit::Middleware, feature_category: :scalability do
  let(:worker) do
    Class.new do
      def self.name
        'ExampleWorker'
      end

      def self.get_concurrency_limit
        0
      end

      def self.configured_concurrency_limit; end
    end
  end

  let(:job) { { 'class' => worker.name, 'args' => [] } }
  let(:service) { Gitlab::SidekiqMiddleware::ConcurrencyLimit::ConcurrencyLimitService }
  let(:middleware) { described_class.new(worker, job) }
  let(:enqueue_limit) { Gitlab::SidekiqMiddleware::ConcurrencyLimit::EnqueueLimit }

  before do
    stub_feature_flags(disable_sidekiq_concurrency_limit_middleware_ExampleWorker: false)
    allow(enqueue_limit).to receive(:enabled_for?).with(worker).and_return(true)
    allow(service).to receive(:enqueue_limit).with(worker.name).and_return(5)
    allow(service).to receive(:has_jobs_in_queue?).with(worker.name).and_return(true)
    allow(Gitlab::SidekiqMiddleware::ConcurrencyLimit::Scope).to receive(:for).with(worker).and_return(nil)
    allow(Gitlab::SidekiqMiddleware::ConcurrencyLimit::FreeSlots).to receive(:enabled_for?).with(worker)
      .and_return(false)
  end

  describe '#schedule' do
    it 'defers with a shared limit even when the local calculated limit is zero' do
      expect(service).to receive(:has_jobs_in_queue?).with(worker.name).once.and_return(true)
      expect(middleware).to receive(:defer_job!)

      expect { |block| middleware.schedule(&block) }.not_to yield_control
    end

    it 'keeps the legacy path when the per-worker rollout is off' do
      allow(enqueue_limit).to receive(:enabled_for?).with(worker).and_return(false)
      expect(service).not_to receive(:enqueue_limit)

      expect { |block| middleware.schedule(&block) }.to yield_control
    end

    it 'falls back to scheduling when no usable limit is available' do
      allow(service).to receive(:enqueue_limit).with(worker.name).and_return(0)

      expect { |block| middleware.schedule(&block) }.to yield_control
    end

    it 'allows jobs without reading limits when there is no backlog' do
      allow(service).to receive(:has_jobs_in_queue?).with(worker.name).and_return(false)
      expect(service).not_to receive(:enqueue_limit)

      expect { |block| middleware.schedule(&block) }.to yield_control
    end

    it 'does not intercept scheduled jobs' do
      job['at'] = 1
      expect(service).not_to receive(:enqueue_limit)

      expect { |block| middleware.schedule(&block) }.to yield_control
    end

    it 'does not intercept resumed jobs' do
      job['concurrency_limit_resume'] = true
      expect(service).not_to receive(:enqueue_limit)

      expect { |block| middleware.schedule(&block) }.to yield_control
    end

    it 'honours a worker bypass' do
      stub_feature_flags(disable_sidekiq_concurrency_limit_middleware_ExampleWorker: true)
      expect(service).not_to receive(:enqueue_limit)

      expect { |block| middleware.schedule(&block) }.to yield_control
    end

    it 'skips backlog and limit reads when the global limiter is disabled' do
      stub_feature_flags(sidekiq_concurrency_limit_middleware: false)
      expect(service).not_to receive(:has_jobs_in_queue?)
      expect(service).not_to receive(:enqueue_limit)

      expect { |block| middleware.schedule(&block) }.to yield_control
    end

    context 'with free-slot admission' do
      before do
        allow(Gitlab::SidekiqMiddleware::ConcurrencyLimit::FreeSlots).to receive(:enabled_for?).with(worker)
          .and_return(true)
      end

      it 'leaves legacy live-limit resolution to the service when rollout is disabled' do
        allow(enqueue_limit).to receive(:enabled_for?).with(worker).and_return(false)
        allow(worker).to receive(:get_concurrency_limit).and_return(5)
        expect(service).not_to receive(:enqueue_limit)
        expect(service).to receive(:free_slot_over_the_limit?).with(worker.name, limit: nil).and_return(false)

        expect { |block| middleware.schedule(&block) }.to yield_control
      end

      it 'admits jobs below the shared admission limit despite the backlog' do
        expect(enqueue_limit).to receive(:enabled_for?).with(worker).once.and_return(true)
        expect(service).to receive(:free_slot_over_the_limit?).with(worker.name, limit: 5).and_return(false)

        expect { |block| middleware.schedule(&block) }.to yield_control
      end

      it 'defers jobs at the shared admission limit' do
        expect(service).to receive(:free_slot_over_the_limit?).with(worker.name, limit: 5).and_return(true)
        expect(middleware).to receive(:defer_job!)

        expect { |block| middleware.schedule(&block) }.not_to yield_control
      end
    end

    context 'with a scope' do
      let(:scope) { instance_double(Gitlab::SidekiqMiddleware::ConcurrencyLimit::Scope, type: :root_namespace) }

      before do
        allow(Gitlab::SidekiqMiddleware::ConcurrencyLimit::Scope).to receive(:for).with(worker).and_return(scope)
        job[Gitlab::SidekiqMiddleware::ConcurrencyLimit::Scope::JOB_KEY] = 'root_namespace:group-1'
        allow(service).to receive(:scope_queued?).with(worker.name, 'root_namespace:group-1').and_return(false)
      end

      it 'does not read limits for a scoped worker with no backlog' do
        allow(service).to receive(:has_jobs_in_queue?).with(worker.name).and_return(false)
        expect(service).not_to receive(:enqueue_limit)

        expect { |block| middleware.schedule(&block) }.to yield_control
      end

      it 'keeps the legacy scoped path without a backlog or worker-wide check' do
        allow(enqueue_limit).to receive(:enabled_for?).with(worker).and_return(false)
        allow(worker).to receive(:get_concurrency_limit).and_return(5)
        allow(service).to receive(:has_jobs_in_queue?).with(worker.name).and_return(false)
        expect(service).not_to receive(:enqueue_limit)
        expect(service).not_to receive(:over_the_limit?)

        expect { |block| middleware.schedule(&block) }.to yield_control
      end

      it 'uses the shared enqueue limit for the worker-wide check' do
        expect(enqueue_limit).to receive(:enabled_for?).with(worker).once.and_return(true)
        expect(service).to receive(:over_the_limit?).with(worker.name, limit: 5).and_return(true)
        expect(middleware).to receive(:defer_job!)

        expect { |block| middleware.schedule(&block) }.not_to yield_control
      end

      it 'leaves legacy scoped live-limit resolution to the service when rollout is disabled' do
        allow(enqueue_limit).to receive(:enabled_for?).with(worker).and_return(false)
        allow(worker).to receive(:get_concurrency_limit).and_return(5)
        expect(service).not_to receive(:enqueue_limit)
        expect(service).to receive(:over_the_limit?).with(worker.name, limit: nil).and_return(false)

        expect { |block| middleware.schedule(&block) }.to yield_control
      end

      it 'admits other scopes when the worker has room' do
        expect(service).to receive(:over_the_limit?).with(worker.name, limit: 5).and_return(false)

        expect { |block| middleware.schedule(&block) }.to yield_control
      end

      it 'defers behind the same scope queue without a worker-wide count' do
        allow(service).to receive(:scope_queued?).with(worker.name, 'root_namespace:group-1').and_return(true)
        allow(middleware).to receive(:count_scope_deferral)
        expect(service).not_to receive(:over_the_limit?)
        expect(middleware).to receive(:defer_job!)

        expect { |block| middleware.schedule(&block) }.not_to yield_control
      end

      context 'when free-slot admission is also enabled' do
        before do
          allow(Gitlab::SidekiqMiddleware::ConcurrencyLimit::FreeSlots).to receive(:enabled_for?).with(worker)
            .and_return(true)
        end

        it 'keeps scope ordering ahead of free slots below the published limit' do
          allow(service).to receive(:scope_queued?).with(worker.name, 'root_namespace:group-1').and_return(true)
          allow(middleware).to receive(:count_scope_deferral)
          expect(service).not_to receive(:free_slot_over_the_limit?)
          expect(middleware).to receive(:defer_job!)

          expect { |block| middleware.schedule(&block) }.not_to yield_control
        end

        context 'when the scope is disabled with scoped jobs still queued' do
          before do
            allow(Gitlab::SidekiqMiddleware::ConcurrencyLimit::Scope).to receive(:for).with(worker).and_return(nil)
          end

          it 'admits below the published limit without checking the old scope queue' do
            expect(middleware).not_to receive(:defer_job!)
            expect(service).not_to receive(:scope_queued?)
            expect(service).to receive(:free_slot_over_the_limit?).with(worker.name, limit: 5).and_return(false)

            expect { |block| middleware.schedule(&block) }.to yield_control
          end

          it 'defers at the published limit without checking the old scope queue' do
            expect(service).not_to receive(:scope_queued?)
            expect(service).to receive(:free_slot_over_the_limit?).with(worker.name, limit: 5).and_return(true)
            expect(middleware).to receive(:defer_job!)

            expect { |block| middleware.schedule(&block) }.not_to yield_control
          end
        end
      end
    end
  end

  describe '#perform' do
    it 'does not change server-side admission to use a published default' do
      expect(service).not_to receive(:enqueue_limit)
      expect(middleware).to receive(:defer_job!)
      allow(middleware).to receive(:track_execution_end)
      allow(middleware).to receive(:cleanup_stale_trackers)

      expect { |block| middleware.perform(&block) }.not_to yield_control
    end
  end
end
