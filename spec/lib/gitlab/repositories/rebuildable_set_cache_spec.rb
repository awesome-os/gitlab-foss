# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Repositories::RebuildableSetCache, :clean_gitlab_redis_repository_cache, feature_category: :source_code_management do
  using RSpec::Parameterized::TableSyntax

  let_it_be(:project) { create(:project) }
  let(:repository) { project.repository }
  let(:namespace) { "#{repository.full_path}:{#{project.id}}" }
  let(:gitlab_cache_namespace) { Gitlab::Redis::Cache::CACHE_NAMESPACE }
  let(:cache) { described_class.new(repository) }

  describe 'TTL constants' do
    it 'defines PENDING_EVENT_TTL as REBUILD_FLAG_TTL' do
      expect(described_class::PENDING_EVENT_TTL).to eq(10.minutes)
    end

    it 'defines REBUILD_FLAG_TTL as 10 minutes' do
      expect(described_class::REBUILD_FLAG_TTL).to eq(10.minutes)
    end

    it 'defines TRUST_TTL as 6 hours' do
      expect(described_class::TRUST_TTL).to eq(6.hours)
    end

    it 'defines TRUST_TTL_JITTER as 30 minutes' do
      expect(described_class::TRUST_TTL_JITTER).to eq(30.minutes)
    end

    it 'defines DRAIN_BATCH_SIZE as 1000' do
      expect(described_class::DRAIN_BATCH_SIZE).to eq(1000)
    end
  end

  describe 'log gating with ref_cache_verbose_logging feature flag' do
    before do
      cache.write(:branch_names, %w[main])
    end

    context 'when ref_cache_verbose_logging is disabled' do
      before do
        stub_feature_flags(ref_cache_verbose_logging: false)
      end

      it 'does not emit info-level logs' do
        expect(Gitlab::AppLogger).not_to receive(:info)

        cache.fetch(:branch_names) { %w[main] }
      end

      it 'still emits error-level logs' do
        allow(Gitlab::Redis::RepositoryCache).to receive(:with).and_wrap_original do |original, &block|
          original.call do |redis|
            allow(redis).to receive(:multi).and_raise(::Redis::ConnectionError, 'Connection refused')
            block.call(redis)
          end
        end

        expect(Gitlab::AppLogger).to receive(:error).with(
          hash_including(
            message: 'rebuild_failed',
            rebuildable_cache: hash_including(
              event: :rebuild_failed,
              cache_key: :branch_names
            )
          )
        )

        expect { cache.write(:branch_names, %w[main feature]) }.to raise_error(::Redis::ConnectionError)
      end
    end
  end

  describe '#cache_key' do
    subject { cache.cache_key(:foo) }

    it 'includes the namespace' do
      is_expected.to eq("#{gitlab_cache_namespace}:foo:#{namespace}:set")
    end
  end

  describe '#pending_key' do
    it 'returns the pending queue key' do
      expect(cache.pending_key(:branch_names))
        .to eq("#{gitlab_cache_namespace}:branch_names:pending:#{namespace}")
    end
  end

  describe '#rebuild_flag_key' do
    it 'returns the rebuild flag key' do
      expect(cache.rebuild_flag_key(:branch_names))
        .to eq("#{gitlab_cache_namespace}:branch_names:rebuild:#{namespace}")
    end
  end

  describe '#trust_key' do
    it 'returns the trust flag key' do
      expect(cache.trust_key(:branch_names))
        .to eq("#{gitlab_cache_namespace}:branch_names:trusted:#{namespace}")
    end
  end

  describe '#trusted?' do
    subject(:trusted) { cache.trusted?(:branch_names) }

    where(:trust_value, :members, :expected) do
      '1'     | %w[main] | true
      '1'     | []       | false
      'empty' | []       | true
      nil     | %w[main] | false
    end

    with_them do
      before do
        Gitlab::Redis::RepositoryCache.with do |redis|
          redis.set(cache.trust_key(:branch_names), trust_value) if trust_value
          redis.sadd(cache.cache_key(:branch_names), members) if members.any?
        end
      end

      it 'checks the trust value and set existence' do
        expect(trusted).to be(expected)
      end
    end

    it 'does not read the set members' do
      expect_next_instance_of(::Redis::MultiConnection) do |multi|
        expect(multi).not_to receive(:smembers)
      end

      trusted
    end

    context 'when Redis error occurs' do
      before do
        allow(Gitlab::Redis::RepositoryCache).to receive(:with)
          .and_raise(::Redis::ConnectionError)
      end

      it 'returns false' do
        expect(trusted).to be false
      end
    end
  end

  describe '#rebuilding?' do
    context 'when rebuild flag is set' do
      before do
        Gitlab::Redis::RepositoryCache.with do |redis|
          redis.set(cache.rebuild_flag_key(:branch_names), "1")
        end
      end

      it 'returns true' do
        expect(cache.rebuilding?(:branch_names)).to be true
      end
    end

    context 'when rebuild flag is not set' do
      it 'returns false' do
        expect(cache.rebuilding?(:branch_names)).to be false
      end
    end

    context 'when Redis error occurs' do
      before do
        allow(Gitlab::Redis::RepositoryCache).to receive(:with)
          .and_raise(::Redis::ConnectionError)
      end

      it 'returns false' do
        expect(cache.rebuilding?(:branch_names)).to be false
      end
    end
  end

  describe '#handle_ref_change' do
    let(:branch_ref) { 'refs/heads/feature-branch' }

    context 'when cache exists and no rebuild in progress' do
      before do
        cache.write(:branch_names, %w[main develop])
      end

      it 'adds a new branch to the cache' do
        cache.handle_ref_change(:branch_names, branch_ref, false)

        expect(cache.read(:branch_names)).to contain_exactly('main', 'develop', 'feature-branch')
      end

      it 'removes a deleted branch from the cache' do
        cache.write(:branch_names, %w[main develop feature-branch])

        cache.handle_ref_change(:branch_names, branch_ref, true)

        expect(cache.read(:branch_names)).to contain_exactly('main', 'develop')
      end

      it 'handles branch names with slashes' do
        cache.handle_ref_change(:branch_names, 'refs/heads/feature/foo/bar', false)

        expect(cache.read(:branch_names)).to include('feature/foo/bar')
      end
    end

    context 'when cache does not exist' do
      it 'does not create the cache' do
        cache.handle_ref_change(:branch_names, branch_ref, false)

        expect(cache.exist?(:branch_names)).to be false
      end

      it 'marks cache as untrusted when adding a ref and SET key is missing', :aggregate_failures do
        Gitlab::Redis::RepositoryCache.with do |redis|
          redis.set(cache.trust_key(:branch_names), described_class::EMPTY_FLAG_VALUE)
        end

        expect(cache.trusted?(:branch_names)).to be true

        cache.handle_ref_change(:branch_names, branch_ref, false)

        expect(cache.trusted?(:branch_names)).to be false
      end

      it 'does not mark cache as untrusted when deleting a ref and SET key is missing' do
        Gitlab::Redis::RepositoryCache.with do |redis|
          redis.set(cache.trust_key(:branch_names), described_class::EMPTY_FLAG_VALUE)
        end

        cache.handle_ref_change(:branch_names, branch_ref, true)

        expect(cache.trusted?(:branch_names)).to be true
      end
    end

    context 'when rebuild is in progress but cache does not exist' do
      before do
        Gitlab::Redis::RepositoryCache.with do |redis|
          redis.set(cache.rebuild_flag_key(:branch_names), '1', ex: 60)
          redis.del(cache.cache_key(:branch_names))
        end
      end

      it 'does not create cache key' do
        cache.handle_ref_change(:branch_names, 'refs/heads/feature', false)

        expect(cache.exist?(:branch_names)).to be false
      end

      it 'still queues event to pending list' do
        cache.handle_ref_change(:branch_names, 'refs/heads/feature', false)

        pending_events = Gitlab::Redis::RepositoryCache.with do |redis|
          redis.lrange(cache.pending_key(:branch_names), 0, -1)
        end

        expect(pending_events).to contain_exactly('+feature')
      end

      it 'queues deletion event even when cache does not exist' do
        cache.handle_ref_change(:branch_names, 'refs/heads/old-branch', true)

        pending_events = Gitlab::Redis::RepositoryCache.with do |redis|
          redis.lrange(cache.pending_key(:branch_names), 0, -1)
        end

        expect(pending_events).to contain_exactly('-old-branch')
      end

      # Regression: dual_write previously did not mark_untrusted when
      # SADD_IF_EXISTS returned -1 (SET key absent), leaving a trusted cache
      # that silently reported the pushed ref as absent.
      context 'when adding a ref via dual_write and the SET key is missing' do
        before do
          # Empty rebuild left the cache trusted but with no SET key.
          Gitlab::Redis::RepositoryCache.with do |redis|
            redis.set(cache.trust_key(:branch_names), described_class::EMPTY_FLAG_VALUE)
            redis.del(cache.cache_key(:branch_names))
          end
        end

        it 'does not silently leave a trusted cache missing the pushed ref' do
          expect(cache.trusted?(:branch_names)).to be true

          cache.handle_ref_change(:branch_names, 'refs/heads/main', false)

          # The add could not be applied to the live set (key absent), so the
          # cache must not remain trusted while reporting the branch as absent.
          aggregate_failures do
            # The pushed ref is preserved for reconciliation.
            pending_events = Gitlab::Redis::RepositoryCache.with do |redis|
              redis.lrange(cache.pending_key(:branch_names), 0, -1)
            end
            expect(pending_events).to contain_exactly('+main')

            # Trust must be invalidated so the next read rebuilds and self-heals,
            # rather than confidently returning a wrong "branch does not exist".
            expect(cache.trusted?(:branch_names)).to be false
          end
        end
      end
    end

    context 'when rebuild is in progress' do
      before do
        cache.write(:branch_names, %w[main])
        Gitlab::Redis::RepositoryCache.with do |redis|
          redis.set(cache.rebuild_flag_key(:branch_names), "1")
        end
      end

      it 'updates the cache and enqueues event' do
        cache.handle_ref_change(:branch_names, branch_ref, false)

        # Cache is updated immediately
        expect(cache.read(:branch_names)).to contain_exactly('main', 'feature-branch')

        # Event is enqueued for rebuild reconciliation
        Gitlab::Redis::RepositoryCache.with do |redis|
          events = redis.lrange(cache.pending_key(:branch_names), 0, -1)
          expect(events).to contain_exactly('+feature-branch')
        end
      end

      it 'enqueues delete events with minus prefix' do
        cache.write(:branch_names, %w[main feature-branch])

        cache.handle_ref_change(:branch_names, branch_ref, true)

        expect(cache.read(:branch_names)).to contain_exactly('main')

        Gitlab::Redis::RepositoryCache.with do |redis|
          events = redis.lrange(cache.pending_key(:branch_names), 0, -1)
          expect(events).to contain_exactly('-feature-branch')
        end
      end

      it 'sets TTL on pending queue' do
        cache.handle_ref_change(:branch_names, branch_ref, false)

        Gitlab::Redis::RepositoryCache.with do |redis|
          ttl = redis.ttl(cache.pending_key(:branch_names))
          expect(ttl).to be_within(10).of(described_class::PENDING_EVENT_TTL.to_i)
        end
      end

      it 'accumulates multiple events in order' do
        cache.handle_ref_change(:branch_names, 'refs/heads/branch-1', false)
        cache.handle_ref_change(:branch_names, 'refs/heads/branch-2', false)
        cache.handle_ref_change(:branch_names, 'refs/heads/branch-1', true)

        Gitlab::Redis::RepositoryCache.with do |redis|
          # LPUSH adds to head, so order is reversed when reading
          events = redis.lrange(cache.pending_key(:branch_names), 0, -1)
          expect(events).to eq(['-branch-1', '+branch-2', '+branch-1'])
        end
      end
    end

    context 'when Redis error occurs during simple_update' do
      before do
        cache.write(:branch_names, %w[main])

        Gitlab::Redis::RepositoryCache.with do |redis|
          redis.set(cache.trust_key(:branch_names), '1')
        end
      end

      it 'marks cache as untrusted and logs error' do
        call_count = 0
        allow(Gitlab::Redis::RepositoryCache).to receive(:with).and_wrap_original do |original, &block|
          original.call do |redis|
            call_count += 1
            # Only stub the first with call (the one inside simple_update)
            allow(redis).to receive(:eval).and_raise(::Redis::ConnectionError, 'Connection refused') if call_count == 1

            block.call(redis)
          end
        end

        expect(Gitlab::AppLogger).to receive(:error).with(
          hash_including(
            message: 'simple_update_failed',
            rebuildable_cache: hash_including(
              event: :simple_update_failed,
              cache_key: :branch_names
            )
          )
        )

        expect(cache.trusted?(:branch_names)).to be true

        expect { cache.handle_ref_change(:branch_names, branch_ref, false) }.to raise_error(::Redis::ConnectionError)

        expect(cache.trusted?(:branch_names)).to be false
      end
    end

    context 'when Redis error occurs during dual_write' do
      before do
        cache.write(:branch_names, %w[main])
        Gitlab::Redis::RepositoryCache.with do |redis|
          redis.set(cache.rebuild_flag_key(:branch_names), "1")
          redis.set(cache.trust_key(:branch_names), '1')
        end
      end

      it 'marks cache as untrusted and logs error' do
        allow(Gitlab::Redis::RepositoryCache).to receive(:with).and_wrap_original do |original, &block|
          original.call do |redis|
            allow(redis).to receive(:pipelined).and_raise(::Redis::ConnectionError, 'Connection refused')
            block.call(redis)
          end
        end

        expect(Gitlab::AppLogger).to receive(:error).with(
          hash_including(
            message: 'dual_write_failed',
            rebuildable_cache: hash_including(
              event: :dual_write_failed,
              cache_key: :branch_names
            )
          )
        )

        expect(cache.trusted?(:branch_names)).to be true

        expect { cache.handle_ref_change(:branch_names, branch_ref, false) }.to raise_error(::Redis::ConnectionError)

        expect(cache.trusted?(:branch_names)).to be false
      end
    end

    context 'with Prometheus metrics', :prometheus, :aggregate_failures do
      it 'records a cold add as a skipped update without revoking trust' do
        expect do
          cache.handle_ref_change(:branch_names, branch_ref, false)
        end.to change { operation_metric_value('update', 'skipped') }.by(1)
          .and not_change { operation_metric_value('update', 'success') }
          .and not_change { operation_metric_value('update', 'error') }
          .and not_change { trust_metric_value('revoked') }
      end

      it 'records one revocation when an add finds a trusted cache without a set' do
        Gitlab::Redis::RepositoryCache.with do |redis|
          redis.set(cache.trust_key(:branch_names), '1')
        end

        expect do
          cache.handle_ref_change(:branch_names, branch_ref, false)
        end.to change { trust_metric_value('revoked') }.by(1)
          .and not_change { trust_metric_value('granted') }
          .and change { operation_metric_value('update', 'skipped') }.by(1)
          .and not_change { operation_metric_value('update', 'success') }
          .and not_change { operation_metric_value('update', 'error') }
        expect(cache.trusted?(:branch_names)).to be(false)
      end

      it 'records revocation only for the first repeated invalidation' do
        Gitlab::Redis::RepositoryCache.with do |redis|
          redis.set(cache.trust_key(:branch_names), '1')
        end

        expect do
          cache.handle_ref_change(:branch_names, branch_ref, false)
          cache.handle_ref_change(:branch_names, branch_ref, false)
        end.to change { trust_metric_value('revoked') }.by(1)
      end

      it 'records success for a simple add to an existing set' do
        cache.write(:branch_names, %w[main])

        expect do
          cache.handle_ref_change(:branch_names, branch_ref, false)
        end.to change { operation_metric_value('update', 'success') }.by(1)
      end

      it 'records skipped for a dual-write add to an absent set and enqueues the event' do
        Gitlab::Redis::RepositoryCache.with do |redis|
          redis.set(cache.rebuild_flag_key(:branch_names), '1')
        end

        expect do
          cache.handle_ref_change(:branch_names, branch_ref, false)
        end.to change { operation_metric_value('update', 'skipped') }.by(1)

        pending_events = Gitlab::Redis::RepositoryCache.with do |redis|
          redis.lrange(cache.pending_key(:branch_names), 0, -1)
        end
        expect(pending_events).to contain_exactly('+feature-branch')
      end

      it 'records success for deletions from existing and absent sets' do
        cache.write(:branch_names, %w[feature-branch])

        expect do
          cache.handle_ref_change(:branch_names, branch_ref, true)
        end.to change { operation_metric_value('update', 'success') }.by(1)

        cache.expire(:branch_names)

        expect do
          cache.handle_ref_change(:branch_names, branch_ref, true)
        end.to change { operation_metric_value('update', 'success') }.by(1)
          .and not_change { operation_metric_value('update', 'skipped') }
      end

      it 'records one error when an update fails' do
        allow(cache).to receive(:rebuilding?).and_raise(StandardError, 'failure')

        expect do
          expect { cache.handle_ref_change(:branch_names, branch_ref, false) }
            .to raise_error(StandardError, 'failure')
        end.to change { operation_metric_value('update', 'error') }.by(1)
      end

      it 'does not turn successful update instrumentation failures into cache errors' do
        error = StandardError.new('metrics failure')
        recorded_statuses = []
        counter = instance_double(Prometheus::Client::Counter)
        allow(Gitlab::Metrics).to receive(:counter).and_return(counter)
        allow(counter).to receive(:increment) do |labels|
          recorded_statuses << labels[:status]
          raise error
        end

        expect(Gitlab::ErrorTracking).to receive(:track_exception)
          .with(error, key: :branch_names, operation: 'update')

        expect { cache.handle_ref_change(:branch_names, branch_ref, false) }.not_to raise_error
        expect(cache.exist?(:branch_names)).to be(false)
        expect(recorded_statuses).to eq(['skipped'])
      end
    end
  end

  describe '#write' do
    subject(:write_cache) { cache.write(:branch_names, %w[main feature]) }

    let(:trust_ttl_offset) { 5.minutes.to_i }

    before do
      allow(cache).to receive(:rand).with(described_class::TRUST_TTL_JITTER.to_i).and_return(trust_ttl_offset)
    end

    it 'writes the values to the cache' do
      write_cache

      expect(cache.read(:branch_names)).to contain_exactly('main', 'feature')
    end

    it 'sets expiration on the cache key' do
      write_cache

      expect(cache.ttl(:branch_names)).to be_within(10).of(2.weeks.to_i)
    end

    it 'marks cache as trusted after write', :aggregate_failures do
      expect(cache.trusted?(:branch_names)).to be false

      write_cache

      expect(cache.trusted?(:branch_names)).to be true
      expect(Gitlab::Redis::RepositoryCache.with { |redis| redis.get(cache.trust_key(:branch_names)) })
        .to eq(described_class::FLAG_VALUE)
    end

    it 'acquires and releases rebuild lock' do
      expect(cache.rebuilding?(:branch_names)).to be false

      # Lock is released after write completes
      write_cache

      expect(cache.rebuilding?(:branch_names)).to be false
    end

    context 'with large value sets' do
      let(:large_value) { (1..1500).map { |i| "branch-#{i}" } }

      it 'handles values larger than 1000 items' do
        cache.write(:branch_names, large_value)

        expect(cache.read(:branch_names).size).to eq(1500)
      end
    end

    context 'when the cache was already rebuilt while waiting for the lock' do
      let(:cached_members) { %w[main develop] }

      before do
        Gitlab::Redis::RepositoryCache.with do |redis|
          redis.sadd(cache.cache_key(:branch_names), cached_members)
          redis.set(cache.trust_key(:branch_names), '1')
        end
      end

      it 'skips the rebuild and logs the reason', :aggregate_failures do
        allow(Gitlab::AppLogger).to receive(:info)
        expect(Gitlab::AppLogger).to receive(:info).with(
          hash_including(
            message: 'rebuild_skipped',
            rebuildable_cache: hash_including(
              event: :rebuild_skipped,
              reason: 'cache already rebuilt'
            )
          )
        )
        expect(Gitlab::AppLogger).not_to receive(:info).with(
          hash_including(message: 'rebuild_started')
        )
        expect(Gitlab::AppLogger).not_to receive(:info).with(
          hash_including(message: 'rebuild_completed')
        )

        cache.write(:branch_names, %w[overwrite-1 overwrite-2])
      end

      it 'returns the already-cached members instead of the new value' do
        result = cache.write(:branch_names, %w[overwrite-1 overwrite-2])

        expect(result).to contain_exactly('main', 'develop')
      end

      it 'does not overwrite the cache with the new value' do
        cache.write(:branch_names, %w[overwrite-1 overwrite-2])

        expect(cache.read(:branch_names)).to contain_exactly('main', 'develop')
      end

      it 'releases the rebuild lock afterwards' do
        cache.write(:branch_names, %w[overwrite-1 overwrite-2])

        expect(cache.rebuilding?(:branch_names)).to be false
      end
    end

    context 'when the post-lock recheck raises' do
      it 'releases the rebuild lock', :aggregate_failures do
        allow(cache).to receive(:read_with_trust).and_raise(Redis::BaseError)

        expect { cache.write(:branch_names, %w[a b]) }.to raise_error(Redis::BaseError)

        expect(cache.rebuilding?(:branch_names)).to be false
      end
    end

    context 'when the cache is absent or untrusted' do
      it 'proceeds to rebuild and marks the cache trusted', :aggregate_failures do
        expect(cache.trusted?(:branch_names)).to be false

        result = cache.write(:branch_names, %w[main feature])

        expect(result).to contain_exactly('main', 'feature')
        expect(cache.read(:branch_names)).to contain_exactly('main', 'feature')
        expect(cache.trusted?(:branch_names)).to be true
      end
    end

    context 'when the set exists but is not trusted' do
      before do
        Gitlab::Redis::RepositoryCache.with do |redis|
          redis.sadd(cache.cache_key(:branch_names), %w[old-1 old-2])
        end
      end

      it 'rebuilds and overwrites the stale set', :aggregate_failures do
        result = cache.write(:branch_names, %w[new-1 new-2])

        expect(result).to contain_exactly('new-1', 'new-2')
        expect(cache.read(:branch_names)).to contain_exactly('new-1', 'new-2')
        expect(cache.trusted?(:branch_names)).to be true
      end
    end

    context 'when the trust flag is set but the set is absent', :prometheus do
      where(:trust_value, :expected_members, :expected_grants) do
        '1'     | %w[new-1 new-2] | 1
        'empty' | [] | 0
      end

      with_them do
        before do
          Gitlab::Redis::RepositoryCache.with do |redis|
            redis.set(cache.trust_key(:branch_names), trust_value)
          end
        end

        it 'only skips rebuilding for an explicit empty trust value', :aggregate_failures do
          result = nil
          expect { result = cache.write(:branch_names, %w[new-1 new-2]) }
            .to change { trust_metric_value('granted') }.by(expected_grants)

          expect(result).to match_array(expected_members)
          expect(cache.read(:branch_names)).to match_array(expected_members)
          expect(cache.trusted?(:branch_names)).to be true
        end
      end
    end

    context 'when another rebuild is in progress' do
      before do
        Gitlab::Redis::RepositoryCache.with do |redis|
          redis.set(cache.rebuild_flag_key(:branch_names), '1')
        end
      end

      it 'skips the rebuild and returns the value' do
        expect(Gitlab::AppLogger).to receive(:info).with(
          hash_including(
            message: 'rebuild_skipped',
            rebuildable_cache: hash_including(
              event: :rebuild_skipped,
              reason: 'another rebuild in progress'
            )
          )
        )

        result = cache.write(:branch_names, %w[main feature])

        expect(result).to eq(%w[main feature])
        # Cache should not be updated
        expect(cache.exist?(:branch_names)).to be false
      end

      it 'does not drain pending queue' do
        Gitlab::Redis::RepositoryCache.with do |redis|
          redis.lpush(cache.pending_key(:branch_names), ['+temp-branch'])
        end

        cache.write(:branch_names, %w[main feature])

        pending_events = Gitlab::Redis::RepositoryCache.with do |redis|
          redis.lrange(cache.pending_key(:branch_names), 0, -1)
        end
        expect(pending_events).to contain_exactly('+temp-branch')
      end

      it 'does not clear the rebuild flag' do
        cache.write(:branch_names, %w[main feature])

        rebuild_flag_exists = Gitlab::Redis::RepositoryCache.with do |redis|
          redis.exists?(cache.rebuild_flag_key(:branch_names))
        end
        expect(rebuild_flag_exists).to be true
      end
    end

    context 'with Prometheus metrics', :prometheus, :aggregate_failures do
      it 'records success and granted trust while preserving the success return value' do
        expect do
          expect(write_cache).to contain_exactly('main', 'feature')
        end.to change { operation_metric_value('rebuild', 'success') }.by(1)
          .and change { trust_metric_value('granted') }.by(1)
      end

      it 'records skipped_locked while returning the original value' do
        Gitlab::Redis::RepositoryCache.with do |redis|
          redis.set(cache.rebuild_flag_key(:branch_names), '1')
        end

        expect do
          expect(write_cache).to eq(%w[main feature])
        end.to change { operation_metric_value('rebuild', 'skipped_locked') }.by(1)
      end

      it 'records skipped_trusted while returning the trusted members' do
        cache.write(:branch_names, %w[trusted winner])

        expect do
          expect(write_cache).to contain_exactly('trusted', 'winner')
        end.to change { operation_metric_value('rebuild', 'skipped_trusted') }.by(1)
      end

      it 'records only error when rebuilding raises' do
        allow(cache).to receive(:read_with_trust).and_raise(StandardError, 'failure')

        expect do
          expect { write_cache }.to raise_error(StandardError, 'failure')
        end.to change { operation_metric_value('rebuild', 'error') }.by(1)
          .and not_change { operation_metric_value('rebuild', 'success') }
      end

      it 'records error when rebuild completion raises' do
        allow(cache).to receive(:mark_rebuild_complete).and_raise(StandardError, 'completion failure')

        expect do
          expect { write_cache }.to raise_error(StandardError, 'completion failure')
        end.to change { operation_metric_value('rebuild', 'error') }.by(1)
          .and not_change { operation_metric_value('rebuild', 'success') }
          .and change { trust_metric_value('granted') }.by(1)
      end

      it 'records error when returning the Redis connection raises' do
        rebuild_committed = false

        allow(cache).to receive(:grant_trust).and_wrap_original do |method, *args|
          method.call(*args).tap { rebuild_committed = true }
        end

        allow(cache).to receive(:with).and_wrap_original do |method, *args, &block|
          result = method.call(*args, &block)
          next result unless rebuild_committed

          rebuild_committed = false
          raise StandardError, 'connection check-in failure'
        end

        expect do
          expect { write_cache }.to raise_error(StandardError, 'connection check-in failure')
        end.to change { operation_metric_value('rebuild', 'error') }.by(1)
          .and not_change { operation_metric_value('rebuild', 'success') }
      end

      it 'records one error and logs rebuild details for a Redis failure' do
        error = Redis::ConnectionError.new('failure')
        allow(cache).to receive(:read_with_trust).and_raise(error)
        expect(cache).to receive(:mark_untrusted).with(:branch_names)
        expect(cache).to receive(:log_event).with(
          :rebuild_failed,
          :branch_names,
          level: :error,
          error_class: error.class.name,
          error_message: error.message
        )

        expect do
          expect { write_cache }.to raise_error(error)
        end.to change { operation_metric_value('rebuild', 'error') }.by(1)
          .and not_change { operation_metric_value('rebuild', 'success') }
      end

      it 'records one error without Redis failure logging when lock acquisition fails' do
        error = StandardError.new('failure')
        allow(cache).to receive(:mark_rebuild_in_progress).and_raise(error)
        expect(cache).not_to receive(:log_event).with(:rebuild_failed, anything, anything)

        expect do
          expect { write_cache }.to raise_error(error)
        end.to change { operation_metric_value('rebuild', 'error') }.by(1)
      end

      it 'logs a Redis failure without revoking trust when lock acquisition raises', :aggregate_failures do
        error = Redis::ConnectionError.new('failure')
        allow(cache).to receive(:mark_rebuild_in_progress).and_raise(error)
        expect(cache).to receive(:log_event).with(
          :rebuild_failed,
          :branch_names,
          level: :error,
          error_class: error.class.name,
          error_message: error.message
        )
        expect(cache).not_to receive(:mark_untrusted)

        expect do
          expect { write_cache }.to raise_error(error)
        end.to change { operation_metric_value('rebuild', 'error') }.by(1)
      end
    end

    describe 'rebuild flag cleanup on exception' do
      let(:canonical_value) { %w[main develop] }

      context 'when exception occurs during write' do
        it 'clears rebuild flag when drain_pending_events raises' do
          first_call = true
          allow(cache).to receive(:drain_pending_events).and_wrap_original do |method, *args|
            if first_call
              first_call = false
              raise Redis::ConnectionError, 'Connection lost'
            end

            method.call(*args)
          end

          expect { cache.write(:branch_names, canonical_value) }.to raise_error(Redis::ConnectionError)

          flag_exists = Gitlab::Redis::RepositoryCache.with do |redis|
            redis.exists?(cache.rebuild_flag_key(:branch_names))
          end

          expect(flag_exists).to be false
        end

        it 'allows subsequent rebuild after exception cleanup' do
          first_call = true
          allow(cache).to receive(:drain_pending_events).and_wrap_original do |method, *args|
            if first_call
              first_call = false
              raise Redis::ConnectionError, 'Connection lost'
            end

            method.call(*args)
          end

          expect { cache.write(:branch_names, canonical_value) }.to raise_error(Redis::ConnectionError)

          result = cache.write(:branch_names, canonical_value)

          expect(result).to contain_exactly('main', 'develop')
          expect(cache.read(:branch_names)).to contain_exactly('main', 'develop')
          expect(cache.trusted?(:branch_names)).to be true
        end
      end

      context 'when flag was not acquired' do
        before do
          Gitlab::Redis::RepositoryCache.with do |redis|
            redis.set(cache.rebuild_flag_key(:branch_names), '1', ex: 60)
          end
        end

        it 'does not clear existing flag on early return' do
          cache.write(:branch_names, canonical_value)

          flag_exists = Gitlab::Redis::RepositoryCache.with do |redis|
            redis.exists?(cache.rebuild_flag_key(:branch_names))
          end

          expect(flag_exists).to be true
        end
      end
    end

    context 'with pending events from concurrent updates' do
      it 'replays events queued before the lock is acquired', :aggregate_failures do
        Gitlab::Redis::RepositoryCache.with do |redis|
          redis.lpush(cache.pending_key(:branch_names), '+concurrent-branch')
          redis.lpush(cache.pending_key(:branch_names), '-main')
        end

        result = cache.write(:branch_names, %w[main feature])

        expect(result).to contain_exactly('feature', 'concurrent-branch')
        expect(cache.read(:branch_names)).to contain_exactly('feature', 'concurrent-branch')
        expect(cache.trusted?(:branch_names)).to be(true)
      end

      it 'drains events arriving during the source read', :aggregate_failures do
        # Simulate events that arrived during the source read
        result = cache.fetch(:branch_names) do
          Gitlab::Redis::RepositoryCache.with do |redis|
            redis.lpush(cache.pending_key(:branch_names), '+concurrent-branch')
            redis.lpush(cache.pending_key(:branch_names), '-main')
          end
          %w[main feature]
        end

        # main was in canonical but deleted by event
        # concurrent-branch was added by event
        expect(result).to contain_exactly('feature', 'concurrent-branch')
        expect(cache.read(:branch_names)).to contain_exactly('feature', 'concurrent-branch')
      end

      it 'handles events arriving during rebuild (post-drain)' do
        # We need to simulate events arriving between pre-drain and post-drain
        # This is tricky to test directly, but we can verify the mechanism works
        # by checking that post-drain events are applied

        call_count = 0
        allow(cache).to receive(:drain_pending_events).and_wrap_original do |method, *args|
          call_count += 1

          if call_count == 2
            # Simulate event arriving during MULTI/EXEC (between pre and post drain)
            Gitlab::Redis::RepositoryCache.with do |redis|
              redis.lpush(cache.pending_key(:branch_names), '+late-branch')
            end
          end

          method.call(*args)
        end

        result = cache.write(:branch_names, %w[main])

        expect(result).to contain_exactly('main', 'late-branch')
      end

      it 'correctly handles add then delete of same branch' do
        result = cache.fetch(:branch_names) do
          Gitlab::Redis::RepositoryCache.with do |redis|
            # dual_write uses LPUSH (adds to head), drain uses RPOP (removes from tail)
            # This is FIFO: first event pushed is first event popped
            # To simulate chronological order (add first, delete second):
            # LPUSH '+temp-branch' - list: [+temp-branch]
            # LPUSH '-temp-branch' - list: [-temp-branch, +temp-branch]
            # RPOP gets +temp-branch first (add), then -temp-branch (delete)
            redis.lpush(cache.pending_key(:branch_names), '+temp-branch')
            redis.lpush(cache.pending_key(:branch_names), '-temp-branch')
          end
          %w[main]
        end

        # temp-branch was added then deleted, so should not be in final result
        expect(result).to contain_exactly('main')
      end

      it 'correctly handles delete then add of same branch' do
        result = cache.fetch(:branch_names) do
          Gitlab::Redis::RepositoryCache.with do |redis|
            # To simulate chronological order (delete first, add second):
            # LPUSH '-existing' - list: [-existing]
            # LPUSH '+existing' - list: [+existing, -existing]
            # RPOP gets -existing first (delete), then +existing (add)
            redis.lpush(cache.pending_key(:branch_names), '-existing')
            redis.lpush(cache.pending_key(:branch_names), '+existing')
          end
          %w[main existing]
        end

        # existing was deleted then re-added, so should be in final result
        expect(result).to contain_exactly('main', 'existing')
      end
    end

    context 'with large number of pending events' do
      it 'handles batch draining correctly' do
        events = Array.new(1500) { |i| "+branch-#{i}" }

        result = cache.fetch(:branch_names) do
          Gitlab::Redis::RepositoryCache.with do |redis|
            redis.lpush(cache.pending_key(:branch_names), events)
          end
          %w[main develop]
        end

        expect(result.size).to eq(1502)
        expect(result).to include('main', 'develop', 'branch-0', 'branch-1499')
      end
    end

    context 'with empty value' do
      it 'writes empty set and processes pending events' do
        result = cache.fetch(:branch_names) do
          Gitlab::Redis::RepositoryCache.with do |redis|
            redis.lpush(cache.pending_key(:branch_names), ['+orphan-branch'])
          end
          []
        end

        expect(result).to contain_exactly('orphan-branch')
      end

      it 'marks cache as trusted even for empty set' do
        cache.write(:branch_names, [])

        expect(cache.trusted?(:branch_names)).to be true
      end

      it 'does not create Redis key for empty set without pending events' do
        cache.write(:branch_names, [])

        expect(cache.exist?(:branch_names)).to be false
      end
    end

    context 'when Redis error occurs' do
      it 'marks cache as untrusted and re-raises' do
        Gitlab::Redis::RepositoryCache.with do |redis|
          redis.set(cache.trust_key(:branch_names), '1')
        end

        allow(Gitlab::Redis::RepositoryCache).to receive(:with).and_wrap_original do |original, &block|
          original.call do |redis|
            allow(redis).to receive(:multi).and_raise(::Redis::ConnectionError, 'Connection refused')
            block.call(redis)
          end
        end

        expect(Gitlab::AppLogger).to receive(:error).with(
          hash_including(
            message: 'rebuild_failed',
            rebuildable_cache: hash_including(
              event: :rebuild_failed,
              cache_key: :branch_names
            )
          )
        )

        expect { write_cache }.to raise_error(::Redis::ConnectionError)

        trust_value = Gitlab::Redis::RepositoryCache.with { |redis| redis.get(cache.trust_key(:branch_names)) }
        expect(trust_value).to be_nil
      end
    end

    context 'when a concurrent expire evicts the set before trust is granted' do
      # UNLINK just before the grant so SCARD (0) differs from the expected size.
      before do
        allow(cache).to receive(:grant_trust).and_wrap_original do |original, *args|
          Gitlab::Redis::RepositoryCache.with do |redis|
            redis.unlink(cache.cache_key(:branch_names))
          end

          original.call(*args)
        end
      end

      it 'refuses trust and logs the set mismatch', :prometheus, :aggregate_failures do
        expect(Gitlab::AppLogger).to receive(:info).with(
          hash_including(
            message: 'rebuild_trust_skipped',
            rebuildable_cache: hash_including(
              event: :rebuild_trust_skipped,
              cache_key: :branch_names,
              reason: 'set mismatch before trust'
            )
          )
        )
        allow(Gitlab::AppLogger).to receive(:info)

        expect { cache.write(:branch_names, %w[main develop]) }
          .to change { trust_metric_value('grant_skipped') }.by(1)

        expect(cache.trusted?(:branch_names)).to be false
      end

      it 'lets a subsequent fetch rebuild instead of serving an empty set', :aggregate_failures do
        cache.write(:branch_names, %w[main develop])

        block_called = false
        result = cache.fetch(:branch_names) do
          block_called = true
          %w[main develop]
        end

        expect(block_called).to be(true)
        expect(result).to contain_exactly('main', 'develop')
      end
    end

    it 'sets the jittered TTL on the non-empty cache trust flag', :aggregate_failures do
      cache.write(:branch_names, %w[main develop])

      ttl, trust_value = Gitlab::Redis::RepositoryCache.with do |redis|
        [redis.ttl(cache.trust_key(:branch_names)), redis.get(cache.trust_key(:branch_names))]
      end
      expected_ttl = described_class::TRUST_TTL.to_i + trust_ttl_offset

      expect(ttl).to be_between(expected_ttl - 2, expected_ttl)
      expect(trust_value).to eq(described_class::FLAG_VALUE)
    end

    it 'sets the jittered TTL on the empty cache trust flag', :aggregate_failures do
      cache.write(:branch_names, [])

      ttl, trust_value = Gitlab::Redis::RepositoryCache.with do |redis|
        [redis.ttl(cache.trust_key(:branch_names)), redis.get(cache.trust_key(:branch_names))]
      end
      expected_ttl = described_class::TRUST_TTL.to_i + trust_ttl_offset

      expect(ttl).to be_between(expected_ttl - 2, expected_ttl)
      expect(trust_value).to eq(described_class::EMPTY_FLAG_VALUE)
    end
  end

  describe '#fetch' do
    let(:block_value) { %w[main develop] }

    context 'when the non-empty trust flag survives an evicted set', :prometheus do
      before do
        Gitlab::Redis::RepositoryCache.with { |redis| redis.set(cache.trust_key(:branch_names), '1') }
      end

      it 'reads the source and rebuilds on an absent miss', :aggregate_failures do
        source = proc { block_value }
        expect(source).to receive(:call).once.and_return(block_value)
        allow(Gitlab::AppLogger).to receive(:info)
        expect(Gitlab::AppLogger).to receive(:info)
          .with(hash_including(message: 'cache_marked_untrusted')).once

        expect do
          expect(cache.fetch(:branch_names) { source.call }).to match_array(block_value)
        end.to change { operation_metric_value('fetch', 'miss_absent') }.by(1)
          .and not_change { operation_metric_value('fetch', 'hit') }
          .and change { trust_metric_value('granted') }.by(1)

        expect(cache.read(:branch_names)).to match_array(block_value)
        expect(cache.trusted?(:branch_names)).to be(true)
      end
    end

    context 'when an event arrives after the final drain', :prometheus do
      it 'refuses empty-cache trust, logs pending events and rebuilds on the next fetch', :aggregate_failures do
        first_grant = true
        allow(cache).to receive(:grant_trust).and_wrap_original do |original, *args|
          if first_grant
            first_grant = false
            cache.handle_ref_change(:branch_names, 'refs/heads/late', false)
          end

          original.call(*args)
        end
        allow(Gitlab::AppLogger).to receive(:info)
        expect(Gitlab::AppLogger).to receive(:info).with(
          hash_including(
            message: 'rebuild_trust_skipped',
            rebuildable_cache: hash_including(
              event: :rebuild_trust_skipped,
              cache_key: :branch_names,
              reason: 'events pending'
            )
          )
        )

        expect { cache.fetch(:branch_names) { [] } }
          .to change { trust_metric_value('grant_skipped') }.by(1)
          .and not_change { trust_metric_value('granted') }
        expect(cache.trusted?(:branch_names)).to be(false)

        source = proc { %w[late] }
        expect(source).to receive(:call).once.and_return(%w[late])
        expect(cache.fetch(:branch_names) { source.call }).to eq(%w[late])
        expect(cache.trusted?(:branch_names)).to be(true)
      end
    end

    context 'when an expire races the overwrite and a ref is queued before the post-drain', :prometheus do
      subject(:fetch_cache) { cache.fetch(:branch_names) { %w[main develop] } }

      before do
        drain_calls = 0
        allow(Gitlab::Redis::RepositoryCache).to receive(:with).and_wrap_original do |original, &block|
          original.call do |redis|
            allow(redis).to receive(:rpop).and_wrap_original do |pop, *args|
              drain_calls += 1
              if drain_calls == 2
                cache.expire(:branch_names)
                cache.handle_ref_change(:branch_names, 'refs/heads/x', false)
              end

              pop.call(*args)
            end

            block.call(redis)
          end
        end
      end

      it 'refuses trust for the partial set and rebuilds on the next fetch', :aggregate_failures do
        expect { expect(fetch_cache).to contain_exactly('main', 'develop', 'x') }
          .to change { trust_metric_value('grant_skipped') }.by(1)
          .and not_change { trust_metric_value('granted') }
        expect(cache.read(:branch_names)).to eq(%w[x])
        expect(cache.trusted?(:branch_names)).to be(false)

        source = proc { %w[main develop x] }
        expect(source).to receive(:call).once.and_call_original
        expect(cache.fetch(:branch_names) { source.call }).to contain_exactly('main', 'develop', 'x')
        expect(cache.trusted?(:branch_names)).to be(true)
      end
    end

    context 'when a ref is created then deleted around the post-drain of an evicted set', :prometheus do
      before do
        cache.write(:branch_names, %w[main])
        Gitlab::Redis::RepositoryCache.with { |redis| redis.unlink(cache.cache_key(:branch_names)) }

        drain_call_count = 0
        allow(cache).to receive(:drain_pending_events).and_wrap_original do |original, *args|
          drain_call_count += 1
          cache.handle_ref_change(:branch_names, 'refs/heads/x', false) if drain_call_count == 2

          original.call(*args)
        end
        allow(cache).to receive(:apply_pending_events).and_wrap_original do |original, *args|
          cache.handle_ref_change(:branch_names, 'refs/heads/x', true)
          original.call(*args)
        end
      end

      where(:rebuild_method, :rebuild_args) do
        :fetch | [:branch_names]
        :write | [:branch_names, %w[main]]
      end

      with_them do
        subject(:rebuild_cache) { cache.public_send(rebuild_method, *rebuild_args) { %w[main] } }

        it 'refuses trust and drops the deleted ref on the next fetch', :aggregate_failures do
          expect { rebuild_cache }
            .to change { trust_metric_value('grant_skipped') }.by(1)
            .and not_change { trust_metric_value('granted') }
            .and change { trust_metric_value('revoked') }.by(1)

          expect(cache.trusted?(:branch_names)).to be(false)
          expect(Gitlab::Redis::RepositoryCache.with { |redis| redis.get(cache.trust_key(:branch_names)) })
            .to be_nil

          source = proc { %w[main] }
          expect(source).to receive(:call).once.and_return(%w[main])
          expect(cache.fetch(:branch_names) { source.call }).to eq(%w[main])
          expect(cache.read(:branch_names)).to eq(%w[main])
          expect(cache.trusted?(:branch_names)).to be(true)
        end
      end
    end

    context 'when a ref changes during the source read' do
      before do
        cache.write(:branch_names, %w[main doomed])
        Gitlab::Redis::RepositoryCache.with { |redis| redis.del(cache.trust_key(:branch_names)) }
      end

      it 'keeps a branch pushed during the source read', :aggregate_failures do
        cache.fetch(:branch_names) do
          snapshot = %w[main doomed]
          cache.handle_ref_change(:branch_names, 'refs/heads/pushed-during-read', false)
          snapshot
        end

        expect(cache.trusted?(:branch_names)).to be(true)
        expect(cache.fetch(:branch_names) { raise 'must be a trusted hit' }).to include('pushed-during-read')
      end

      it 'does not resurrect a branch deleted during the source read', :aggregate_failures do
        cache.fetch(:branch_names) do
          snapshot = %w[main doomed]
          cache.handle_ref_change(:branch_names, 'refs/heads/doomed', true)
          snapshot
        end

        expect(cache.trusted?(:branch_names)).to be(true)
        expect(cache.fetch(:branch_names) { raise 'must be a trusted hit' }).not_to include('doomed')
      end

      it 'holds the rebuild lock while reading the source' do
        lock_held = nil
        cache.fetch(:branch_names) do
          lock_held = cache.rebuilding?(:branch_names)
          block_value
        end

        expect(lock_held).to be(true)
      end
    end

    context 'when the cache becomes trusted before acquiring the lock', :prometheus do
      it 'does not call the source and records skipped_trusted', :aggregate_failures do
        allow(cache).to receive(:mark_rebuild_in_progress).and_wrap_original do |original, key|
          described_class.new(repository).write(key, %w[winner])
          original.call(key)
        end

        source = proc { %w[loser] }
        expect(source).not_to receive(:call)

        expect do
          expect(cache.fetch(:branch_names) { source.call }).to eq(%w[winner])
        end.to change { operation_metric_value('rebuild', 'skipped_trusted') }.by(1)
      end

      it 'skips the source when the trusted cache is empty and the set key is absent', :aggregate_failures do
        allow(cache).to receive(:mark_rebuild_in_progress).and_wrap_original do |original, key|
          described_class.new(repository).write(key, [])
          original.call(key)
        end

        source = proc { %w[loser] }
        expect(source).not_to receive(:call)

        expect do
          expect(cache.fetch(:branch_names) { source.call }).to eq([])
        end.to change { operation_metric_value('rebuild', 'skipped_trusted') }.by(1)
        expect(cache.exist?(:branch_names)).to be(false)
      end
    end

    context 'when another rebuild holds the lock', :prometheus do
      before do
        Gitlab::Redis::RepositoryCache.with do |redis|
          redis.set(cache.rebuild_flag_key(:branch_names), '1', ex: 60)
        end
      end

      it 'calls the source once and returns its value', :aggregate_failures do
        source = proc { block_value }
        expect(source).to receive(:call).once.and_return(block_value)

        expect(cache.fetch(:branch_names) { source.call }).to eq(block_value)
      end

      it 'records a fetch error but no rebuild metric if the source raises', :aggregate_failures do
        expect do
          expect { cache.fetch(:branch_names) { raise 'source failed' } }.to raise_error('source failed')
        end.to change { operation_metric_value('fetch', 'error') }.by(1)
          .and not_change { operation_metric_value('rebuild', 'error') }
          .and not_change { operation_metric_value('rebuild', 'skipped_locked') }
      end

      it 'keeps trust and logs no rebuild failure if the source raises a Redis error', :aggregate_failures do
        allow(cache).to receive(:log_event).and_call_original
        expect(cache).not_to receive(:log_event).with(:rebuild_failed, any_args)
        expect(cache).not_to receive(:mark_untrusted)

        expect do
          expect do
            cache.fetch(:branch_names) do
              Gitlab::Redis::RepositoryCache.with { |redis| redis.set(cache.trust_key(:branch_names), '1') }
              raise Redis::BaseError, 'source failed'
            end
          end.to raise_error(Redis::BaseError, 'source failed')
        end.to change { operation_metric_value('fetch', 'error') }.by(1)
          .and not_change { operation_metric_value('rebuild', 'error') }

        expect(Gitlab::Redis::RepositoryCache.with { |redis| redis.get(cache.trust_key(:branch_names)) })
          .to eq(described_class::FLAG_VALUE)
      end
    end

    context 'when the source raises under the rebuild lock', :prometheus do
      let(:rebuild_errors_before_read) { operation_metric_value('rebuild', 'error') }

      before do
        rebuild_errors_before_read
        cache.fetch(:branch_names) do
          cache.handle_ref_change(:branch_names, 'refs/heads/queued', false)
          raise 'source failed'
        end
      rescue RuntimeError => error
        raise unless error.message == 'source failed'
      end

      it 'releases the lock and preserves pending ref changes', :aggregate_failures do
        expect(operation_metric_value('rebuild', 'error')).to eq(rebuild_errors_before_read + 1)
        expect(cache.rebuilding?(:branch_names)).to be(false)
        pending = Gitlab::Redis::RepositoryCache.with do |redis|
          redis.lrange(cache.pending_key(:branch_names), 0, -1)
        end
        expect(pending).to contain_exactly('+queued')
      end

      it 'replays pending ref changes on a subsequent write', :aggregate_failures do
        expect(cache.write(:branch_names, %w[main])).to contain_exactly('main', 'queued')
        expect(cache.trusted?(:branch_names)).to be(true)
      end

      it 'drops events queued before fetch takes the lock', :aggregate_failures do
        result = cache.fetch(:branch_names) { %w[main] }

        expect(result).to contain_exactly('main')
        expect(cache.read(:branch_names)).to contain_exactly('main')
        expect(cache.trusted?(:branch_names)).to be(true)
        pending = Gitlab::Redis::RepositoryCache.with do |redis|
          redis.lrange(cache.pending_key(:branch_names), 0, -1)
        end
        expect(pending).to be_empty
      end
    end

    context 'when cache exists and is trusted' do
      before do
        cache.write(:branch_names, %w[cached_branch])
      end

      it 'returns cached value without calling the block' do
        expect { |b| cache.fetch(:branch_names, &b) }.not_to yield_control
        expect(cache.fetch(:branch_names) { block_value }).to contain_exactly('cached_branch')
      end

      it 'logs the cache hit' do
        expect(Gitlab::AppLogger).to receive(:info).with(
          hash_including(
            message: 'cache_hit',
            rebuildable_cache: hash_including(
              event: :cache_hit,
              cache_key: :branch_names
            )
          )
        )

        cache.fetch(:branch_names) { block_value }
      end

      it 'returns cached data after incremental updates' do
        cache.handle_ref_change(:branch_names, 'refs/heads/hotfix', false)

        result = cache.fetch(:branch_names) { block_value }

        expect(result).to contain_exactly('cached_branch', 'hotfix')
      end
    end

    context 'when cache exists but is not trusted' do
      before do
        cache.write(:branch_names, %w[stale_branch])
        # Manually mark as untrusted
        Gitlab::Redis::RepositoryCache.with do |redis|
          redis.del(cache.trust_key(:branch_names))
        end
      end

      it 'calls the block and rebuilds the cache' do
        result = cache.fetch(:branch_names) { block_value }

        expect(result).to contain_exactly('main', 'develop')
        expect(cache.read(:branch_names)).to contain_exactly('main', 'develop')
      end

      it 'marks cache as trusted after rebuild' do
        expect(cache.trusted?(:branch_names)).to be false

        cache.fetch(:branch_names) { block_value }

        expect(cache.trusted?(:branch_names)).to be true
      end

      it 'logs cache miss with trust info' do
        expect(Gitlab::AppLogger).to receive(:info).with(
          hash_including(
            message: 'cache_miss',
            rebuildable_cache: hash_including(
              event: :cache_miss,
              cache_key: :branch_names,
              exists: true,
              trusted: false
            )
          )
        ).ordered

        allow(Gitlab::AppLogger).to receive(:info)

        cache.fetch(:branch_names) { block_value }
      end
    end

    context 'when cache does not exist' do
      it 'does not log a trust revocation' do
        allow(Gitlab::AppLogger).to receive(:info)
        expect(Gitlab::AppLogger).not_to receive(:info).with(hash_including(message: 'cache_marked_untrusted'))

        cache.fetch(:branch_names) { block_value }
      end

      it 'calls the block and caches the result' do
        result = cache.fetch(:branch_names) { block_value }

        expect(result).to contain_exactly('main', 'develop')
        expect(cache.read(:branch_names)).to contain_exactly('main', 'develop')
      end

      it 'logs cache miss with exists info' do
        expect(Gitlab::AppLogger).to receive(:info).with(
          hash_including(
            message: 'cache_miss',
            rebuildable_cache: hash_including(
              event: :cache_miss,
              cache_key: :branch_names,
              exists: false,
              trusted: false
            )
          )
        ).ordered

        allow(Gitlab::AppLogger).to receive(:info)

        cache.fetch(:branch_names) { block_value }
      end

      it 'sets cache expiry' do
        cache.fetch(:branch_names) { block_value }

        ttl = cache.ttl(:branch_names)
        expect(ttl).to be > 0
        expect(ttl).to be <= 2.weeks
      end
    end

    context 'when cache was written with empty values (0 branches/tags)' do
      before do
        cache.write(:branch_names, [])
      end

      it 'returns empty array without calling the block and records a hit', :prometheus, :aggregate_failures do
        source = proc { %w[should_not_be_called] }
        expect(source).not_to receive(:call)

        expect do
          expect(cache.fetch(:branch_names) { source.call }).to eq([])
        end.to change { operation_metric_value('fetch', 'hit') }.by(1)
          .and not_change { operation_metric_value('fetch', 'miss_absent') }
          .and not_change { operation_metric_value('fetch', 'miss_untrusted') }
      end

      it 'logs cache hit with count 0' do
        expect(Gitlab::AppLogger).to receive(:info).with(
          hash_including(
            message: 'cache_hit',
            rebuildable_cache: hash_including(
              event: :cache_hit,
              cache_key: :branch_names,
              count: 0
            )
          )
        )

        cache.fetch(:branch_names) { [] }
      end

      it 'self-heals when a branch is added to a previously empty project' do
        # Trust flag is set but key doesn't exist after writing empty set
        expect(cache.trusted?(:branch_names)).to be true
        expect(cache.exist?(:branch_names)).to be false

        # A branch is created - simple_update detects the SET key is missing
        # and marks cache as untrusted
        cache.handle_ref_change(:branch_names, 'refs/heads/new-branch', false)
        expect(cache.trusted?(:branch_names)).to be false

        # Next fetch triggers a full rebuild and picks up the new branch
        result = cache.fetch(:branch_names) { %w[new-branch] }

        expect(result).to contain_exactly('new-branch')
        expect(cache.trusted?(:branch_names)).to be true
      end
    end

    context 'when block raises an error' do
      it 'propagates the error' do
        expect do
          cache.fetch(:branch_names) { raise StandardError, 'Git fetch failed' }
        end.to raise_error(StandardError, 'Git fetch failed')
      end

      it 'does not populate the cache' do
        begin
          cache.fetch(:branch_names) { raise StandardError }
        rescue StandardError
          # expected
        end

        expect(cache.exist?(:branch_names)).to be false
      end

      it 'does not mark cache as trusted' do
        begin
          cache.fetch(:branch_names) { raise StandardError }
        rescue StandardError
          # expected
        end

        expect(cache.trusted?(:branch_names)).to be false
      end
    end

    context 'with pending events from previous failed rebuild' do
      before do
        Gitlab::Redis::RepositoryCache.with do |redis|
          redis.lpush(cache.pending_key(:branch_names), ['+orphan-feature', '-main'])
        end
      end

      it 'does not replay stale pending events during rebuild' do
        result = cache.fetch(:branch_names) { %w[main develop] }

        expect(result).to contain_exactly('main', 'develop')
        expect(cache.read(:branch_names)).to contain_exactly('main', 'develop')
      end

      it 'clears the pending queue' do
        cache.fetch(:branch_names) { %w[main develop] }

        pending_events = Gitlab::Redis::RepositoryCache.with do |redis|
          redis.lrange(cache.pending_key(:branch_names), 0, -1)
        end

        expect(pending_events).to be_empty
      end
    end

    context 'with Prometheus metrics', :prometheus, :aggregate_failures do
      it 'records a hit for a trusted read' do
        cache.write(:branch_names, %w[main])

        expect { cache.fetch(:branch_names) { block_value } }
          .to change { operation_metric_value('fetch', 'hit') }.by(1)
          .and not_change { operation_metric_value('fetch', 'miss_untrusted') }
          .and not_change { operation_metric_value('fetch', 'miss_absent') }
      end

      it 'records an untrusted miss and the nested rebuild after fallback succeeds' do
        cache.write(:branch_names, %w[stale_branch])
        Gitlab::Redis::RepositoryCache.with do |redis|
          redis.del(cache.trust_key(:branch_names))
        end

        expect { cache.fetch(:branch_names) { block_value } }
          .to change { operation_metric_value('fetch', 'miss_untrusted') }.by(1)
          .and not_change { operation_metric_value('fetch', 'miss_absent') }
          .and change { operation_metric_value('rebuild', 'success') }.by(1)
      end

      it 'records an absent miss and the nested rebuild after fallback succeeds' do
        expect { cache.fetch(:branch_names) { block_value } }
          .to change { operation_metric_value('fetch', 'miss_absent') }.by(1)
          .and not_change { operation_metric_value('fetch', 'miss_untrusted') }
          .and change { operation_metric_value('rebuild', 'success') }.by(1)
      end

      it 'records an untrusted miss when an absent set rebuilds to an empty result' do
        expect { cache.fetch(:branch_names) { [] } }
          .to change { operation_metric_value('fetch', 'miss_untrusted') }.by(1)
          .and not_change { operation_metric_value('fetch', 'miss_absent') }
          .and change { operation_metric_value('rebuild', 'success') }.by(1)
      end

      it 'records only error when fallback raises' do
        expect do
          expect { cache.fetch(:branch_names) { raise StandardError, 'failure' } }
            .to raise_error(StandardError, 'failure')
        end.to change { operation_metric_value('fetch', 'error') }.by(1)
          .and not_change { operation_metric_value('fetch', 'miss_untrusted') }
          .and not_change { operation_metric_value('fetch', 'miss_absent') }
      end
    end
  end

  describe '#search' do
    context 'when the non-empty trust flag survives an evicted set' do
      before do
        Gitlab::Redis::RepositoryCache.with { |redis| redis.set(cache.trust_key(:branch_names), '1') }
      end

      it 'matches the source in memory without populating the cache', :aggregate_failures do
        source = proc { %w[feature/new main] }
        expect(source).to receive(:call).once.and_return(%w[feature/new main])

        result = cache.search(:branch_names, 'feature/*') { source.call }

        expect(result.to_a).to contain_exactly('feature/new')
        expect(cache.exist?(:branch_names)).to be(false)
      end
    end

    context 'when cache exists and is trusted' do
      before do
        cache.write(:branch_names, %w[main feature/foo feature/bar develop])
      end

      it 'returns matching entries without calling the block' do
        expect { |b| cache.search(:branch_names, 'feature/*', &b) }.not_to yield_control

        results = cache.search(:branch_names, 'feature/*') { [] }.to_a
        expect(results).to contain_exactly('feature/foo', 'feature/bar')
      end

      it 'returns matching entries for exact pattern' do
        result = cache.search(:branch_names, 'main') { [] }

        expect(result.to_a).to contain_exactly('main')
      end

      it 'returns matching entries for wildcard suffix pattern' do
        result = cache.search(:branch_names, '*foo') { [] }

        expect(result.to_a).to contain_exactly('feature/foo')
      end

      it 'returns empty enumerator when no matches' do
        result = cache.search(:branch_names, 'nonexistent/*') { [] }

        expect(result.to_a).to be_empty
      end

      it 'returns an Enumerator' do
        result = cache.search(:branch_names, '*') { [] }

        expect(result).to be_an(Enumerator)
      end

      it 'reflects incremental updates' do
        cache.handle_ref_change(:branch_names, 'refs/heads/feature/new-feature', false)

        result = cache.search(:branch_names, 'feature/*') { [] }

        expect(result.to_a).to contain_exactly('feature/foo', 'feature/bar', 'feature/new-feature')
      end

      it 'reflects incremental deletions' do
        cache.handle_ref_change(:branch_names, 'refs/heads/feature/foo', true)

        result = cache.search(:branch_names, 'feature/*') { [] }

        expect(result.to_a).to contain_exactly('feature/bar')
      end
    end

    context 'when cache exists but is not trusted' do
      before do
        cache.write(:branch_names, %w[stale/branch])
        Gitlab::Redis::RepositoryCache.with do |redis|
          redis.del(cache.trust_key(:branch_names))
        end
      end

      it 'matches source values without rebuilding or granting trust', :aggregate_failures do
        results = cache.search(:branch_names, 'feature/*') { %w[feature/new main] }.to_a

        expect(results).to contain_exactly('feature/new')
        expect(cache.read(:branch_names)).to contain_exactly('stale/branch')
        expect(cache.trusted?(:branch_names)).to be false
      end

      it 'does not return stale data' do
        result = cache.search(:branch_names, 'stale/*') { %w[main develop] }

        expect(result.to_a).to be_empty
      end
    end

    context 'when cache does not exist' do
      it 'matches the source without populating the cache', :aggregate_failures do
        results = cache.search(:branch_names, 'feat*') { %w[feat-1 feat-2 other] }.to_a

        expect(results).to contain_exactly('feat-1', 'feat-2')
        expect(cache.exist?(:branch_names)).to be(false)
      end

      it 'returns an Enumerator' do
        expect(cache.search(:branch_names, '*') { %w[main] }).to be_an(Enumerator)
      end

      it 'matches across slashes and leading dots' do
        results = cache.search(:branch_names, '*') { %w[feature/foo .hidden] }.to_a

        expect(results).to contain_exactly('feature/foo', '.hidden')
      end

      it 'returns no results for a pattern containing a NUL byte' do
        expect(cache.search(:branch_names, "main\0") { %w[main] }.to_a).to be_empty
      end

      it 'includes ref changes reconciled during the rebuild' do
        drain_call_count = 0
        allow(cache).to receive(:drain_pending_events).and_wrap_original do |method, *args|
          drain_call_count += 1
          # The second drain is perform_rebuild's post-drain, simulating a ref change racing the overwrite.
          cache.handle_ref_change(:branch_names, 'refs/heads/feat-late', false) if drain_call_count == 2

          method.call(*args)
        end

        results = cache.search(:branch_names, 'feat*') { cache.fetch(:branch_names) { %w[feat-1 other] } }.to_a

        expect(results).to contain_exactly('feat-1', 'feat-late')
      end
    end

    context 'when another rebuild holds the lock' do
      before do
        Gitlab::Redis::RepositoryCache.with do |redis|
          redis.set(cache.rebuild_flag_key(:branch_names), '1', ex: 60)
        end
      end

      it 'matches the source values when the cache does not exist', :aggregate_failures do
        results = cache.search(:branch_names, 'feat*') { %w[feat-1 feat-2 other] }.to_a

        expect(results).to contain_exactly('feat-1', 'feat-2')
        expect(cache.trusted?(:branch_names)).to be(false)
      end

      it 'matches the source values instead of a stale cache' do
        Gitlab::Redis::RepositoryCache.with do |redis|
          redis.sadd(cache.cache_key(:branch_names), %w[stale/branch])
        end

        results = cache.search(:branch_names, '*') { %w[main] }.to_a

        expect(results).to contain_exactly('main')
      end
    end

    context 'when cache was written with empty values' do
      before do
        cache.write(:branch_names, [])
      end

      it 'returns empty results without calling the block', :aggregate_failures do
        expect { |b| cache.search(:branch_names, '*', &b) }.not_to yield_control
        expect(cache.search(:branch_names, '*') { %w[should_not_rebuild] }.to_a).to eq([])
      end
    end

    context 'with special characters in pattern' do
      before do
        cache.write(:branch_names, %w[release-1.0 release-1.1 release-2.0 test-release])
      end

      it 'handles dot character in pattern' do
        result = cache.search(:branch_names, 'release-1.*') { [] }

        expect(result.to_a).to contain_exactly('release-1.0', 'release-1.1')
      end

      it 'handles question mark single character wildcard' do
        result = cache.search(:branch_names, 'release-?.0') { [] }

        expect(result.to_a).to contain_exactly('release-1.0', 'release-2.0')
      end

      it 'handles bracket character class' do
        result = cache.search(:branch_names, 'release-[12].0') { [] }

        expect(result.to_a).to contain_exactly('release-1.0', 'release-2.0')
      end
    end

    context 'when iterating lazily' do
      before do
        branches = Array.new(100) { |i| "branch-#{i.to_s.rjust(3, '0')}" }
        cache.write(:branch_names, branches)
      end

      it 'supports lazy enumeration' do
        result = cache.search(:branch_names, 'branch-0*') { [] }

        first_five = result.take(5)

        expect(first_five.size).to eq(5)
        expect(first_five).to all(start_with('branch-0'))
      end

      it 'supports chaining with other Enumerable methods' do
        result = cache.search(:branch_names, 'branch-*') { [] }

        count = result.count { |b| b.end_with?('0') }

        expect(count).to eq(10)
      end
    end

    context 'with Prometheus metrics', :prometheus, :aggregate_failures do
      it 'records hit when constructing the lazy enumerator without forcing iteration' do
        cache.write(:branch_names, %w[main])

        result = nil
        expect { result = cache.search(:branch_names, '*') { [] } }
          .to change { operation_metric_value('search', 'hit') }.by(1)
          .and not_change { operation_metric_value('search', 'miss_untrusted') }
          .and not_change { operation_metric_value('search', 'miss_absent') }

        expect(result).to be_an(Enumerator)
      end

      it 'records an untrusted miss without rebuilding the cache' do
        cache.write(:branch_names, %w[stale_branch])
        Gitlab::Redis::RepositoryCache.with do |redis|
          redis.del(cache.trust_key(:branch_names))
        end

        expect { cache.search(:branch_names, '*') { %w[main] } }
          .to change { operation_metric_value('search', 'miss_untrusted') }.by(1)
          .and not_change { operation_metric_value('search', 'miss_absent') }
          .and not_change { operation_metric_value('rebuild', 'success') }
      end

      it 'records an absent miss without rebuilding the cache' do
        expect { cache.search(:branch_names, '*') { %w[main] } }
          .to change { operation_metric_value('search', 'miss_absent') }.by(1)
          .and not_change { operation_metric_value('search', 'miss_untrusted') }
      end

      it 'records an untrusted miss when the source is empty' do
        expect { cache.search(:branch_names, '*') { [] } }
          .to change { operation_metric_value('search', 'miss_untrusted') }.by(1)
          .and not_change { operation_metric_value('search', 'miss_absent') }
      end

      it 'records only error when fallback raises' do
        expect do
          expect { cache.search(:branch_names, '*') { raise StandardError, 'failure' } }
            .to raise_error(StandardError, 'failure')
        end.to change { operation_metric_value('search', 'error') }.by(1)
          .and not_change { operation_metric_value('search', 'miss_untrusted') }
          .and not_change { operation_metric_value('search', 'miss_absent') }
      end
    end
  end

  describe '#try_include?' do
    where(:description, :cache_state, :value, :expected, :status) do
      'trusted cache, existing member'       | :trusted       | 'main'        | [true, true]   | 'hit'
      'trusted cache, non-existing member'   | :trusted       | 'nonexistent' | [false, true]  | 'hit'
      'trusted empty cache, any member'      | :trusted_empty | 'main'        | [false, false] | 'hit'
      'evicted set, surviving trust flag'    | :evicted       | 'main'        | [false, false] | 'miss_absent'
      'untrusted cache, existing member'     | :untrusted     | 'main'        | [false, false] | 'miss_untrusted'
      'untrusted cache, non-existing member' | :untrusted     | 'nonexistent' | [false, false] | 'miss_untrusted'
      'no cache, any member'                 | :no_cache      | 'main'        | [false, false] | 'miss_absent'
    end

    with_them do
      let(:other_statuses) { %w[hit miss_untrusted miss_absent] - [status] }

      before do
        next if cache_state == :no_cache

        cache.write(:branch_names, cache_state == :trusted_empty ? [] : %w[main develop])

        if cache_state == :evicted
          Gitlab::Redis::RepositoryCache.with { |redis| redis.unlink(cache.cache_key(:branch_names)) }
        end

        if cache_state == :untrusted
          Gitlab::Redis::RepositoryCache.with do |redis|
            redis.del(cache.trust_key(:branch_names))
          end
        end
      end

      it 'returns membership and records the cache status', :prometheus, :aggregate_failures do
        expect do
          expect(cache.try_include?(:branch_names, value)).to eq(expected)
        end.to change { operation_metric_value('include', status) }.by(1)
          .and not_change { other_statuses.map { |other_status| operation_metric_value('include', other_status) } }
      end
    end

    context 'when cache is updated incrementally' do
      before do
        cache.write(:branch_names, %w[main])
      end

      it 'reflects the added ref' do
        cache.handle_ref_change(:branch_names, 'refs/heads/feature', false)

        expect(cache.try_include?(:branch_names, 'feature')).to eq([true, true])
      end
    end

    context 'when trust has expired and a ref is added via handle_ref_change' do
      before do
        cache.write(:branch_names, %w[main develop])
        # Simulate trust expiry - cache set still exists but is no longer trusted
        Gitlab::Redis::RepositoryCache.with do |redis|
          redis.del(cache.trust_key(:branch_names))
        end
      end

      it 'returns [false, false] for the newly added ref' do
        # simple_update successfully adds the ref to the existing set
        cache.handle_ref_change(:branch_names, 'refs/heads/new-branch', false)

        # Despite the ref being present in the set, try_include? returns
        # [false, false] because the cache is untrusted, forcing the caller
        # to take the cold-cache path and trigger a full rebuild.
        expect(cache.try_include?(:branch_names, 'new-branch')).to eq([false, false])
      end
    end

    context 'with Prometheus metrics', :prometheus, :aggregate_failures do
      it 'records error when the Redis transaction raises' do
        allow(Gitlab::Redis::RepositoryCache).to receive(:with).and_raise(StandardError, 'failure')

        expect do
          expect { cache.try_include?(:branch_names, 'main') }.to raise_error(StandardError, 'failure')
        end.to change { operation_metric_value('include', 'error') }.by(1)
          .and not_change { operation_metric_value('include', 'miss_untrusted') }
          .and not_change { operation_metric_value('include', 'miss_absent') }
      end
    end
  end

  describe '#expire' do
    before do
      cache.write(:branch_names, %w[main])
      cache.write(:tag_names, %w[v1.0])
    end

    it 'removes the specified keys' do
      cache.expire(:branch_names)

      expect(cache.exist?(:branch_names)).to be false
      expect(cache.exist?(:tag_names)).to be true
    end

    it 'can expire multiple keys' do
      cache.expire(:branch_names, :tag_names)

      expect(cache.exist?(:branch_names)).to be false
      expect(cache.exist?(:tag_names)).to be false
    end

    it 'returns the number of set keys deleted', :aggregate_failures do
      expect(cache.expire(:branch_names)).to eq(1)
      expect(cache.expire(:branch_names)).to eq(0)
    end

    it 'sums the deleted count across multiple keys' do
      expect(cache.expire(:branch_names, :tag_names)).to eq(2)
    end

    it 'only logs a trust revocation for the first repeated expiration', :aggregate_failures do
      allow(Gitlab::AppLogger).to receive(:info)
      expect(Gitlab::AppLogger).to receive(:info)
        .with(hash_including(message: 'cache_marked_untrusted')).once
      expect(Gitlab::AppLogger).to receive(:info)
        .with(hash_including(message: 'cache_expired')).twice

      cache.expire(:branch_names)
      cache.expire(:branch_names)
    end

    context 'when expiring a key that is not backed by this set cache' do
      it 'does not log cache_marked_untrusted or cache_expired' do
        expect(Gitlab::AppLogger).not_to receive(:info).with(
          hash_including(rebuildable_cache: hash_including(cache_key: :branch_count))
        )

        cache.expire(:branch_count)
      end

      it 'logs only for the set-backed key in a mixed batch and still returns the deleted count', :aggregate_failures do
        allow(Gitlab::AppLogger).to receive(:info)
        expect(Gitlab::AppLogger).not_to receive(:info).with(
          hash_including(rebuildable_cache: hash_including(cache_key: :branch_count))
        )
        expect(Gitlab::AppLogger).to receive(:info).with(
          hash_including(rebuildable_cache: hash_including(event: :cache_expired, cache_key: :branch_names))
        )

        expect(cache.expire(:branch_names, :branch_count)).to eq(1)
      end

      it 'expires non-set-backed keys via the parent without touching a trust key', :aggregate_failures do
        Gitlab::Redis::RepositoryCache.with do |redis|
          redis.sadd(cache.cache_key(:merged_branch_names), %w[a b])
        end

        expect(cache.expire(:merged_branch_names)).to eq(1)
        expect(cache.exist?(:merged_branch_names)).to be(false)
      end
    end

    context 'with Prometheus metrics', :prometheus, :aggregate_failures do
      it 'records revoked trust for symbol and string set-backed keys' do
        expect { cache.expire(:branch_names) }.to change { trust_metric_value('revoked', 'branch') }.by(1)
        expect { cache.expire('tag_names') }.to change { trust_metric_value('revoked', 'tag') }.by(1)
      end

      it 'does not record a trust event for another key' do
        expect { cache.expire(:branch_count) }.not_to change { trust_metric_value('revoked') }
      end

      it 'records revocation only for removed trust keys and preserves the deletion sum' do
        Gitlab::Redis::RepositoryCache.with do |redis|
          redis.del(cache.trust_key(:tag_names))
          redis.sadd(cache.cache_key(:merged_branch_names), 'merged')
        end

        expect do
          expect(cache.expire(:branch_names, :tag_names, :merged_branch_names)).to eq(3)
        end.to change { trust_metric_value('revoked', 'branch') }.by(1)
          .and not_change { trust_metric_value('revoked', 'tag') }
      end

      it 'records revocation only for the first repeated expiration' do
        expect do
          expect(cache.expire(:branch_names)).to eq(1)
          expect(cache.expire(:branch_names)).to eq(0)
        end.to change { trust_metric_value('revoked') }.by(1)
      end
    end

    # Regression for the production incident where branch_names was served as a
    # trusted cache_hit with 0 members.
    #
    # #expire is inherited from Gitlab::SetCache and only UNLINKs the set key.
    # It has no knowledge of the RebuildableSetCache trust flag. Legacy callers
    # such as Repository#expire_branches_cache (invoked by after_create_branch /
    # before_remove_branch, which are NOT gated by the feature flag) therefore
    # delete the populated set while leaving the trust flag dangling. The next
    # #fetch then sees an empty set that is still trusted and serves it as a
    # cache_hit with 0 members instead of rebuilding.
    context 'when expiring a trusted key (regression)' do
      it 'clears the set and trust flag but preserves the rebuild lock and pending queue', :aggregate_failures do
        cache.write(:branch_names, %w[main develop feature])

        Gitlab::Redis::RepositoryCache.with do |redis|
          redis.set(cache.rebuild_flag_key(:branch_names), '1')
          redis.lpush(cache.pending_key(:branch_names), '+feature')
        end

        expect(cache.exist?(:branch_names)).to be(true)
        expect(cache.trusted?(:branch_names)).to be(true)

        cache.expire(:branch_names)

        rebuild_flag_exists, pending_events = Gitlab::Redis::RepositoryCache.with do |redis|
          [
            redis.exists?(cache.rebuild_flag_key(:branch_names)),
            redis.lrange(cache.pending_key(:branch_names), 0, -1)
          ]
        end

        # The set key is gone, and the trust flag must not outlive the set it
        # vouches for. Otherwise the next #fetch serves a trusted-but-empty set.
        expect(cache.exist?(:branch_names)).to be(false)
        expect(cache.trusted?(:branch_names)).to be(false)
        # The rebuild lock and pending events belong to a concurrent #write and
        # must survive an expire.
        expect(rebuild_flag_exists).to be(true)
        expect(pending_events).to eq(['+feature'])
      end

      it 'causes a subsequent fetch to rebuild instead of serving an empty set', :aggregate_failures do
        cache.write(:branch_names, %w[main develop feature])
        cache.expire(:branch_names)

        block_called = false
        result = cache.fetch(:branch_names) do
          block_called = true
          %w[main develop feature]
        end

        # Because trust was cleared by #expire, fetch misses and rebuilds from
        # the canonical source rather than serving the empty stranded set.
        expect(block_called).to be(true)
        expect(result).to contain_exactly('main', 'develop', 'feature')
      end

      it 'logs a cache_expired event for the affected key' do
        cache.write(:branch_names, %w[main develop feature])

        allow(Gitlab::AppLogger).to receive(:info)
        expect(Gitlab::AppLogger).to receive(:info).with(
          hash_including(
            message: 'cache_expired',
            rebuildable_cache: hash_including(
              event: :cache_expired,
              cache_key: :branch_names
            )
          )
        )

        cache.expire(:branch_names)
      end

      it 'logs both cache_marked_untrusted and cache_expired for the affected key', :aggregate_failures do
        cache.write(:branch_names, %w[main develop feature])

        allow(Gitlab::AppLogger).to receive(:info)
        expect(Gitlab::AppLogger).to receive(:info).with(
          hash_including(
            message: 'cache_marked_untrusted',
            rebuildable_cache: hash_including(
              event: :cache_marked_untrusted,
              cache_key: :branch_names
            )
          )
        )
        expect(Gitlab::AppLogger).to receive(:info).with(
          hash_including(
            message: 'cache_expired',
            rebuildable_cache: hash_including(
              event: :cache_expired,
              cache_key: :branch_names
            )
          )
        )

        cache.expire(:branch_names)
      end
    end

    context 'when expiring with no keys' do
      it 'returns 0' do
        expect(cache.expire).to eq(0)
      end
    end

    # A non-atomic expire lets a rebuild re-grant trust between DEL and UNLINK.
    # Inject that grant after standalone DEL; atomic Lua has no such gap.
    # Check the raw flag because readers now reject trust on a missing set.
    context 'when a concurrent rebuild grants trust during the expire (residual race regression)' do
      let(:expire_in_progress) { { active: false } }

      def expire_with_concurrent_trust_grant
        expire_in_progress[:active] = true
        cache.expire(:branch_names)
      ensure
        expire_in_progress[:active] = false
      end

      before do
        allow(Gitlab::Redis::RepositoryCache).to receive(:with).and_wrap_original do |original, &block|
          original.call do |redis|
            allow(redis).to receive(:del).and_wrap_original do |del_method, *keys|
              result = del_method.call(*keys)

              if expire_in_progress[:active] && keys.include?(cache.trust_key(:branch_names))
                redis.eval(
                  described_class::GRANT_TRUST_SCRIPT,
                  keys: [
                    cache.cache_key(:branch_names), cache.trust_key(:branch_names), cache.pending_key(:branch_names)
                  ],
                  argv: [
                    described_class::TRUST_TTL.to_i, described_class::FLAG_VALUE,
                    redis.scard(cache.cache_key(:branch_names))
                  ]
                )
              end

              result
            end

            block.call(redis)
          end
        end
      end

      it 'does not leave a trust flag for the expired set', :aggregate_failures do
        cache.write(:branch_names, %w[main develop feature])
        expire_with_concurrent_trust_grant

        trust_value = Gitlab::Redis::RepositoryCache.with { |redis| redis.get(cache.trust_key(:branch_names)) }

        expect(trust_value).to be_nil
        expect(cache.read(:branch_names)).to be_empty
      end

      it 'causes a subsequent fetch to rebuild instead of serving an empty set', :aggregate_failures do
        cache.write(:branch_names, %w[main develop feature])
        expire_with_concurrent_trust_grant

        block_called = false
        result = cache.fetch(:branch_names) do
          block_called = true
          %w[main develop feature]
        end

        expect(block_called).to be(true)
        expect(result).to contain_exactly('main', 'develop', 'feature')
      end
    end
  end

  describe '#initialize' do
    context 'when the repository has no project' do
      let(:repository) { instance_double(Repository, full_path: 'group/wiki', project: nil) }

      it 'raises an ArgumentError' do
        expect { described_class.new(repository) }
          .to raise_error(ArgumentError, described_class::MISSING_PROJECT_ERROR)
      end
    end

    it 'builds a namespace with the {project.id} hash tag' do
      expect(cache.namespace).to eq("#{repository.full_path}:{#{project.id}}")
    end

    it 'co-locates the set, trust and pending keys on the same Redis Cluster slot', :aggregate_failures do
      hash_tag = ->(key) { key[/\{(.*?)\}/, 1] || key }
      slot = ->(key) { ::RedisClient::Cluster::KeySlotConverter.convert(hash_tag.call(key)) }

      set_key = cache.cache_key(:branch_names)
      trust_key = cache.trust_key(:branch_names)

      expect(slot.call(set_key)).to eq(slot.call(trust_key))
      expect(slot.call(set_key)).to eq(slot.call(cache.pending_key(:branch_names)))
    end
  end

  describe 'with extra_namespace' do
    let(:cache) { described_class.new(repository, extra_namespace: 'extra') }

    it 'includes extra namespace in cache key' do
      expect(cache.cache_key(:foo)).to eq("#{gitlab_cache_namespace}:foo:#{namespace}:extra:set")
    end
  end

  describe 'with custom expires_in' do
    let(:cache) { described_class.new(repository, expires_in: 1.hour) }

    it 'uses custom expiration' do
      cache.write(:branch_names, %w[main])

      expect(cache.ttl(:branch_names)).to be_within(10).of(1.hour.to_i)
    end
  end

  describe 'pending event TTL' do
    it 'equals REBUILD_FLAG_TTL so queued events last as long as a rebuild' do
      expect(described_class::PENDING_EVENT_TTL).to eq(described_class::REBUILD_FLAG_TTL)
    end

    it 'is shorter than TRUST_TTL' do
      expect(described_class::PENDING_EVENT_TTL).to be < described_class::TRUST_TTL
    end
  end

  describe 'rebuild flag lifecycle' do
    let(:key) { :branch_names }

    it 'sets and clears rebuild flag during write' do
      flag_states = []

      allow(cache).to receive(:drain_pending_events).and_wrap_original do |method, *args|
        flag_exists = Gitlab::Redis::RepositoryCache.with do |redis|
          redis.exists?(cache.rebuild_flag_key(key))
        end
        flag_states << { during_drain: flag_exists }
        method.call(*args)
      end

      cache.write(key, %w[main develop])

      expect(flag_states.first[:during_drain]).to be true

      final_flag_exists = Gitlab::Redis::RepositoryCache.with do |redis|
        redis.exists?(cache.rebuild_flag_key(key))
      end
      expect(final_flag_exists).to be false
    end

    it 'sets rebuild flag with correct TTL' do
      allow(cache).to receive(:drain_pending_events).and_wrap_original do |method, *args|
        ttl = Gitlab::Redis::RepositoryCache.with do |redis|
          redis.ttl(cache.rebuild_flag_key(key))
        end
        expect(ttl).to be > 0
        expect(ttl).to be <= described_class::REBUILD_FLAG_TTL
        method.call(*args)
      end

      cache.write(key, %w[main develop])
    end
  end

  describe 'integration: push during rebuild lifecycle' do
    let(:key) { :branch_names }

    context 'when push arrives before initial drain' do
      it 'includes the pushed branch in final cache state' do
        cache.write(key, %w[main develop])

        drain_call_count = 0

        allow(cache).to receive(:drain_pending_events).and_wrap_original do |method, *args|
          drain_call_count += 1

          cache.handle_ref_change(key, 'refs/heads/feature-from-push', false) if drain_call_count == 1

          method.call(*args)
        end

        Gitlab::Redis::RepositoryCache.with do |redis|
          redis.del(cache.trust_key(key))
          redis.del(cache.rebuild_flag_key(key))
        end

        canonical_branches = %w[main develop hotfix]
        result = cache.write(key, canonical_branches)

        expect(result).to contain_exactly('main', 'develop', 'hotfix', 'feature-from-push')
        expect(cache.read(key)).to contain_exactly('main', 'develop', 'hotfix', 'feature-from-push')
      end

      it 'includes deleted branch in final cache state' do
        cache.write(key, %w[main develop feature-to-delete])

        drain_call_count = 0

        allow(cache).to receive(:drain_pending_events).and_wrap_original do |method, *args|
          drain_call_count += 1

          cache.handle_ref_change(key, 'refs/heads/feature-to-delete', true) if drain_call_count == 1

          method.call(*args)
        end

        Gitlab::Redis::RepositoryCache.with do |redis|
          redis.del(cache.trust_key(key))
          redis.del(cache.rebuild_flag_key(key))
        end

        canonical_branches = %w[main develop feature-to-delete]
        result = cache.write(key, canonical_branches)

        expect(result).to contain_exactly('main', 'develop')
        expect(cache.read(key)).to contain_exactly('main', 'develop')
      end
    end
  end

  describe '#write with pending events edge cases' do
    let(:key) { :branch_names }

    context 'when pending queue contains blank events' do
      it 'skips blank events and processes valid ones' do
        result = cache.fetch(key) do
          Gitlab::Redis::RepositoryCache.with do |redis|
            # Add mix of valid and blank events (LPUSH adds to head, RPOP removes from tail)
            # Order of processing: +valid-branch, '', +another-branch
            redis.lpush(cache.pending_key(key), '+valid-branch')
            redis.lpush(cache.pending_key(key), '')
            redis.lpush(cache.pending_key(key), '+another-branch')
          end
          %w[main]
        end

        # Blank event should be skipped, valid events should be processed
        expect(result).to contain_exactly('main', 'valid-branch', 'another-branch')
      end
    end
  end

  describe 'concurrent rebuilds' do
    let(:key) { :branch_names }
    let(:canonical_value) { %w[main develop] }

    describe 'rebuild flag prevents concurrent rebuilds' do
      context 'when another rebuild is already in progress' do
        before do
          Gitlab::Redis::RepositoryCache.with do |redis|
            redis.set(cache.rebuild_flag_key(key), '1', ex: 60)
          end
        end

        it 'skips rebuild and returns provided value' do
          result = cache.write(key, canonical_value)

          expect(result).to eq(canonical_value)
        end

        it 'does not overwrite existing cache' do
          Gitlab::Redis::RepositoryCache.with do |redis|
            redis.sadd(cache.cache_key(key), %w[existing-branch])
          end

          cache.write(key, canonical_value)

          expect(cache.read(key)).to contain_exactly('existing-branch')
        end

        it 'does not drain pending queue' do
          Gitlab::Redis::RepositoryCache.with do |redis|
            redis.lpush(cache.pending_key(key), ['+pending-branch'])
          end

          cache.write(key, canonical_value)

          pending_events = Gitlab::Redis::RepositoryCache.with do |redis|
            redis.lrange(cache.pending_key(key), 0, -1)
          end

          expect(pending_events).to contain_exactly('+pending-branch')
        end

        it 'does not clear the rebuild flag' do
          cache.write(key, canonical_value)

          flag_exists = Gitlab::Redis::RepositoryCache.with do |redis|
            redis.exists?(cache.rebuild_flag_key(key))
          end

          expect(flag_exists).to be true
        end

        it 'does not mark cache as trusted' do
          cache.write(key, canonical_value)

          expect(cache.trusted?(key)).to be false
        end
      end
    end

    describe 'rebuild flag TTL safety' do
      it 'sets rebuild flag with TTL to prevent deadlock' do
        ttl_during_rebuild = nil

        allow(cache).to receive(:drain_pending_events).and_wrap_original do |method, *args|
          ttl_during_rebuild = Gitlab::Redis::RepositoryCache.with do |redis|
            redis.ttl(cache.rebuild_flag_key(key))
          end
          method.call(*args)
        end

        cache.write(key, canonical_value)

        expect(ttl_during_rebuild).to be > 0
        expect(ttl_during_rebuild).to be <= described_class::REBUILD_FLAG_TTL
      end

      it 'clears rebuild flag after successful completion' do
        cache.write(key, canonical_value)

        flag_exists = Gitlab::Redis::RepositoryCache.with do |redis|
          redis.exists?(cache.rebuild_flag_key(key))
        end

        expect(flag_exists).to be false
      end
    end
  end

  def operation_metric_value(operation, status, ref_type = 'branch')
    metric = Gitlab::Metrics.client.get(:gitlab_ref_cache_operations_total)

    metric&.get(operation: operation, ref_type: ref_type, status: status).to_f
  end

  def trust_metric_value(event, ref_type = 'branch')
    metric = Gitlab::Metrics.client.get(:gitlab_ref_cache_trust_events_total)

    metric&.get(ref_type: ref_type, event: event).to_f
  end
end
