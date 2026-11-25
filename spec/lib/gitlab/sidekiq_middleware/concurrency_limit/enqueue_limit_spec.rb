# frozen_string_literal: true

require 'spec_helper'
require 'sidekiq/config'

RSpec.describe Gitlab::SidekiqMiddleware::ConcurrencyLimit::EnqueueLimit, feature_category: :scalability do
  let(:worker) do
    Class.new do
      def self.name
        'ExampleWorker'
      end

      def self.configured_concurrency_limit; end

      def self.queue
        'urgent_other'
      end

      def self.get_sidekiq_options
        { 'store' => 'main' }
      end
    end
  end

  let(:redis) { instance_double(Redis) }
  let(:key) { 'sidekiq:concurrency_limit:{example_worker}:default_limit:urgent_other:main' }

  before do
    stub_const('Gitlab::SidekiqMiddleware::ConcurrencyLimit::EnqueueLimit::CACHE',
      Concurrent::Map.new)
    allow(Gitlab::Redis::QueuesMetadata).to receive(:with).and_yield(redis)
    allow(Gitlab::SidekiqSharding::Router).to receive(:get_shard_instance).with('main').and_return(['main', nil])
  end

  describe '.read' do
    it 'shares a published default across repeated reads' do
      expect(redis).to receive(:get).with(key).once.and_return('5')

      expect(Array.new(100) { described_class.read(worker) }).to all(eq(5))
    end

    it 'caches a missing publication rather than reading once per job' do
      expect(redis).to receive(:get).with(key).once.and_return(nil)

      expect(Array.new(100) { described_class.read(worker) }).to all(be_nil)
    end

    it 'retains a known unlimited default' do
      allow(redis).to receive(:get).with(key).and_return('0')

      expect(described_class.read(worker)).to eq(0)
    end

    it 'refreshes after one second', :aggregate_failures do
      now = Gitlab::Metrics::System.monotonic_time
      allow(Gitlab::Metrics::System).to receive(:monotonic_time).and_return(now)
      expect(redis).to receive(:get).with(key).ordered.and_return('5')
      expect(described_class.read(worker)).to eq(5)

      allow(Gitlab::Metrics::System).to receive(:monotonic_time).and_return(now + 1)
      expect(redis).to receive(:get).with(key).ordered.and_return('8')

      expect(described_class.read(worker)).to eq(8)
    end

    it 'stops using an expired Redis publication after the local cache expires', :aggregate_failures do
      now = Gitlab::Metrics::System.monotonic_time
      allow(Gitlab::Metrics::System).to receive(:monotonic_time).and_return(now)
      allow(redis).to receive(:get).with(key).and_return('5', nil)
      expect(described_class.read(worker)).to eq(5)

      allow(Gitlab::Metrics::System).to receive(:monotonic_time).and_return(now + 1)

      expect(described_class.read(worker)).to be_nil
    end

    it 'does not block another worker on a slow cache refresh', :aggregate_failures do
      other_worker = Class.new(worker) do
        def self.name
          'OtherWorker'
        end
      end
      entered = Queue.new
      release = Queue.new
      finished = Queue.new
      expect(redis).to receive(:get).with(key) do
        entered.push(true)
        release.pop
        '5'
      end
      expect(redis).to receive(:get)
        .with('sidekiq:concurrency_limit:{other_worker}:default_limit:urgent_other:main').and_return('8')

      first = Thread.new { described_class.read(worker) }
      expect(entered.pop(timeout: 2)).to be(true)
      second = Thread.new { finished.push(described_class.read(other_worker)) }

      expect(finished.pop(timeout: 2)).to eq(8)
      release.push(true)
      expect(first.value).to eq(5)
      second.join
    ensure
      first&.kill
      second&.kill
    end

    it 'does not reuse a default after queue routing changes', :aggregate_failures do
      expect(redis).to receive(:get).with(key).and_return('5')
      expect(described_class.read(worker)).to eq(5)

      allow(worker).to receive(:queue).and_return('another_queue')
      expect(redis).to receive(:get)
        .with('sidekiq:concurrency_limit:{example_worker}:default_limit:another_queue:main').and_return(nil)

      expect(described_class.read(worker)).to be_nil
    end

    it 'caches a Redis failure as a missing publication for one second', :aggregate_failures do
      now = Gitlab::Metrics::System.monotonic_time
      allow(Gitlab::Metrics::System).to receive(:monotonic_time).and_return(now)
      error = Redis::BaseError.new('unavailable')
      expect(redis).to receive(:get).with(key).once.and_raise(error)
      expect(Gitlab::ErrorTracking).to receive(:track_exception).with(error, worker_class: worker.name).once

      expect(Array.new(100) { described_class.read(worker) }).to all(be_nil)

      allow(Gitlab::Metrics::System).to receive(:monotonic_time).and_return(now + 1)
      expect(redis).to receive(:get).with(key).and_return('5')

      expect(described_class.read(worker)).to eq(5)
    end

    it 'does not reuse a default after Redis shard routing changes', :aggregate_failures do
      expect(redis).to receive(:get).with(key).and_return('5')
      expect(described_class.read(worker)).to eq(5)

      allow(Gitlab::SidekiqSharding::Router).to receive(:get_shard_instance).with('main')
        .and_return(['queues_shard_catchall_a', nil])
      expect(redis).to receive(:get)
        .with('sidekiq:concurrency_limit:{example_worker}:default_limit:urgent_other:queues_shard_catchall_a')
        .and_return(nil)

      expect(described_class.read(worker)).to be_nil
    end
  end

  describe '.enabled_for?' do
    it 'enables the new path only for the selected worker' do
      expect(described_class.enabled_for?(worker)).to be(true)
    end

    it 'disables the new path when the worker rollout flag is off' do
      stub_feature_flags(sidekiq_concurrency_limit_enqueue_ExampleWorker: false)

      expect(described_class.enabled_for?(worker)).to be(false)
    end

    it 'does not check a flag for an unresolved worker' do
      expect(Feature).not_to receive(:enabled?)

      expect(described_class.enabled_for?(nil)).to be(false)
    end
  end

  describe '.publish' do
    before do
      allow(described_class).to receive(:enabled_for?).with(worker).and_return(true)
      allow(Gitlab::Runtime).to receive(:sidekiq?).and_return(true)
      allow(ENV).to receive(:fetch).and_call_original
      allow(ENV).to receive(:fetch).with('GITLAB_SIDEKIQ_MAX_REPLICAS', '0').and_return('10')
      allow(ENV).to receive(:fetch).with('SIDEKIQ_CONCURRENCY', '0').and_return('20')
      allow(ENV).to receive(:fetch).with('SIDEKIQ_SHARD_NAME', anything).and_return('main')
      allow(Sidekiq).to receive(:default_configuration).and_return(instance_double(Sidekiq::Config,
        queues: ['urgent_other']))
      allow(Gitlab::SidekiqSharding::Router).to receive(:get_shard_instance).with('main').and_return(['main', nil])
    end

    it 'publishes an expiring default for its own queue' do
      expect(redis).to receive(:set).with(key, 5, ex: 330)

      described_class.publish(worker, 5)
    end

    it 'queues the write on a given pipeline' do
      pipeline = instance_double(Redis::PipelinedConnection)
      expect(pipeline).to receive(:set).with(key, 5, ex: 330)
      expect(redis).not_to receive(:set)

      described_class.publish(worker, 5, pipeline: pipeline)
    end

    it 'reports publication failures without stopping the metrics sampler' do
      error = Redis::BaseError.new('unavailable')
      allow(redis).to receive(:set).with(key, 5, ex: 330).and_raise(error)
      expect(Gitlab::ErrorTracking).to receive(:track_exception).with(error, worker_class: worker.name)

      expect { described_class.publish(worker, 5) }.not_to raise_error
    end

    it 'does not publish from a web process' do
      allow(Gitlab::Runtime).to receive(:sidekiq?).and_return(false)
      expect(redis).not_to receive(:set)

      described_class.publish(worker, 0)
    end

    it 'does not publish without shard capacity settings' do
      allow(ENV).to receive(:fetch).with('SIDEKIQ_CONCURRENCY', '0').and_return('0')
      expect(redis).not_to receive(:set)

      described_class.publish(worker, 0)
    end

    it 'does not publish without a maximum replica count' do
      allow(ENV).to receive(:fetch).with('GITLAB_SIDEKIQ_MAX_REPLICAS', '0').and_return('0')
      expect(redis).not_to receive(:set)

      described_class.publish(worker, 0)
    end

    it 'does not publish when the rollout flag is off' do
      allow(described_class).to receive(:enabled_for?).with(worker).and_return(false)
      expect(redis).not_to receive(:set)

      described_class.publish(worker, 5)
    end

    it 'does not publish explicit worker limits' do
      allow(worker).to receive(:configured_concurrency_limit).and_return(3)
      expect(redis).not_to receive(:set)

      described_class.publish(worker, 3)
    end

    it 'does not publish for a queue the process does not serve' do
      allow(Sidekiq).to receive(:default_configuration).and_return(instance_double(Sidekiq::Config, queues: ['other']))
      expect(redis).not_to receive(:set)

      described_class.publish(worker, 5)
    end

    it 'does not publish for a different Redis queue shard' do
      allow(ENV).to receive(:fetch).with('SIDEKIQ_SHARD_NAME', anything).and_return('queues_shard_catchall_a')
      expect(redis).not_to receive(:set)

      described_class.publish(worker, 5)
    end
  end
end
