# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Redis::RateLimiting do
  include_examples "redis_new_instance_shared_examples", 'rate_limiting', Gitlab::Redis::Cache

  describe '.log_if_using_cache_config' do
    include TmpdirHelper

    subject(:log_if_using_cache_config) { described_class.log_if_using_cache_config }

    let(:rails_root) { mktmpdir }
    let(:redis_yml) { { 'cache' => 'redis://cache:6379' } }

    # Both stores read a real redis.yml, so the spec sees whatever shape params really has.
    before do
      FileUtils.mkdir_p(File.join(rails_root, 'config'))
      File.write(File.join(rails_root, 'config/redis.yml'), { 'test' => redis_yml }.to_json)

      [described_class, Gitlab::Redis::Cache].each do |klass|
        allow(klass).to receive(:config_file_name).and_call_original
        allow(klass).to receive(:rails_root).and_return(rails_root)
        clear_cached_params(klass)
      end

      allow(Gitlab::AppLogger).to receive(:info)
    end

    after do
      [described_class, Gitlab::Redis::Cache].each { |klass| clear_cached_params(klass) }
    end

    def clear_cached_params(klass)
      klass.remove_instance_variable(:@params) if klass.instance_variable_defined?(:@params)
    end

    context 'when it falls back to the Cache config' do
      it 'logs that it uses the Cache config' do
        log_if_using_cache_config

        expect(Gitlab::AppLogger).to have_received(:info).with(
          message: 'Rate limiting Redis uses the same config as Cache',
          store: 'RateLimiting',
          fallback_store: 'Cache'
        )
      end
    end

    context 'when it has its own config' do
      let(:redis_yml) { super().merge('rate_limiting' => 'redis://rate-limiting:6379') }

      it 'logs nothing' do
        log_if_using_cache_config

        expect(Gitlab::AppLogger).not_to have_received(:info)
      end
    end

    context 'when only resque.yml has an entry' do
      let(:redis_yml) { {} }

      before do
        File.write(File.join(rails_root, 'config/resque.yml'), { 'test' => 'redis://resque:6379' }.to_json)
      end

      it 'logs that it uses the Cache config' do
        log_if_using_cache_config

        expect(Gitlab::AppLogger).to have_received(:info).with(
          message: 'Rate limiting Redis uses the same config as Cache',
          store: 'RateLimiting',
          fallback_store: 'Cache'
        )
      end
    end
  end

  describe '.with_suppressed_errors' do
    subject(:ping) { described_class.with_suppressed_errors(&:ping) }

    before do
      allow(described_class).to receive(:with).and_yield(redis)
    end

    context 'when using Redis' do
      let(:redis) { described_class.send(:init_redis, { url: 'redis://127.0.0.0:0' }) }

      it 'tracks the error and returns nil' do
        expect(Gitlab::ErrorTracking).to receive(:track_and_raise_for_dev_exception)
          .with(a_kind_of(::Redis::CannotConnectError))

        expect(ping).to be_nil
      end
    end

    context 'when using RedisCluster' do
      let(:redis) do
        described_class.send(:init_redis, {
          nodes: [
            { host: '127.0.0.0', port: 0, db: 1 },
            { host: '127.0.0.0', port: 0, db: 2 },
            { host: '127.0.0.0', port: 0, db: 3 }
          ]
        })
      end

      it 'tracks the error and returns nil' do
        expect(Gitlab::ErrorTracking).to receive(:track_and_raise_for_dev_exception)
          .with(a_kind_of(::Redis::Cluster::InitialSetupError))

        expect(ping).to be_nil
      end
    end

    context 'with a RedisClient exception' do
      let(:redis) { instance_double(Redis) }

      before do
        allow(redis).to receive(:ping).and_raise(::RedisClient::ReadTimeoutError)
      end

      it 'tracks the error and returns nil' do
        expect(Gitlab::ErrorTracking).to receive(:track_and_raise_for_dev_exception)
          .with(a_kind_of(::RedisClient::ReadTimeoutError))

        expect(ping).to be_nil
      end
    end
  end
end
