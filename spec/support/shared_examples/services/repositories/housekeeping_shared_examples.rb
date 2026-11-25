# frozen_string_literal: true

RSpec.shared_examples 'housekeeps repository' do
  subject { described_class.new(resource) }

  context 'with a clean redis state', :clean_gitlab_redis_shared_state, :aggregate_failures do
    describe '#execute' do
      it 'enqueues a sidekiq job' do
        expect(subject).to receive(:try_obtain_lease).and_return(:the_uuid)
        expect(subject).to receive(:lease_key).and_return(:the_lease_key)
        expect(subject).to receive(:task).and_return(:incremental_repack)
        expect(resource.git_garbage_collect_worker_klass).to receive(:perform_async).with(resource.id, :incremental_repack, :the_lease_key, :the_uuid).and_call_original

        Sidekiq::Testing.fake! do
          expect { subject.execute }.to change { resource.git_garbage_collect_worker_klass.jobs.size }.by(1)
        end
      end

      it 'yields the block if given' do
        expect do |block|
          subject.execute(&block)
        end.to yield_with_no_args
      end

      it 'resets counter after execution' do
        expect(subject).to receive(:try_obtain_lease).and_return(:the_uuid)
        allow(subject).to receive(:gc_period).and_return(1)
        resource.increment_pushes_since_gc

        perform_enqueued_jobs do
          expect { subject.execute }.to change { resource.pushes_since_gc }.to(0)
        end
      end

      context 'when no lease can be obtained' do
        before do
          expect(subject).to receive(:try_obtain_lease).and_return(false)
        end

        it 'does not enqueue a job' do
          expect(resource.git_garbage_collect_worker_klass).not_to receive(:perform_async)

          expect { subject.execute }.to raise_error(::Repositories::HousekeepingService::LeaseTaken)
        end

        it 'does not reset pushes_since_gc' do
          expect do
            expect { subject.execute }.to raise_error(::Repositories::HousekeepingService::LeaseTaken)
          end.not_to change { resource.pushes_since_gc }
        end

        it 'does not yield' do
          expect do |block|
            expect { subject.execute(&block) }
              .to raise_error(::Repositories::HousekeepingService::LeaseTaken)
          end.not_to yield_with_no_args
        end
      end

      context 'task type' do
        it 'goes through all three housekeeping tasks, executing only the highest task when there is overlap' do
          allow(subject).to receive_messages(try_obtain_lease: :the_uuid, lease_key: :the_lease_key)

          # At push 200
          expect(resource.git_garbage_collect_worker_klass).to receive(:perform_async).with(resource.id, :gc, :the_lease_key, :the_uuid)
            .once
          # At push 10, 20, ... (except the gc call)
          expect(resource.git_garbage_collect_worker_klass).to receive(:perform_async).with(resource.id, :incremental_repack, :the_lease_key, :the_uuid)
            .exactly(19).times

          201.times do
            subject.increment!
            subject.execute if subject.needed?
          end

          expect(resource.pushes_since_gc).to eq(1)
        end
      end

      it 'runs the task specifically requested' do
        housekeeping = described_class.new(resource, :gc)

        allow(housekeeping).to receive_messages(try_obtain_lease: :gc_uuid, lease_key: :gc_lease_key)

        expect(resource.git_garbage_collect_worker_klass).to receive(:perform_async).with(resource.id, :gc, :gc_lease_key, :gc_uuid).twice

        2.times do
          housekeeping.execute
        end
      end
    end

    describe '#needed?' do
      it 'when the count is low enough' do
        expect(subject.needed?).to be(false)
      end

      it 'when the count is high enough' do
        allow(resource).to receive(:pushes_since_gc).and_return(10)
        expect(subject.needed?).to be(true)
      end

      it 'when incremental repack period is not multiple of gc period' do
        allow(Gitlab::CurrentSettings).to receive(:housekeeping_incremental_repack_period).and_return(12)
        allow(resource).to receive(:pushes_since_gc).and_return(200)

        expect(subject.needed?).to be(true)
      end
    end

    describe '#increment!' do
      it 'increments the pushes_since_gc counter' do
        expect { subject.increment! }.to change { resource.pushes_since_gc }.by(1)
      end
    end

    describe 'push counter round trips' do
      let(:feature_flag_actor) { resource.is_a?(Wiki) ? resource.container : resource }

      def counter_commands(&block)
        RedisCommands::Recorder.new(pattern: 'pushes_since_gc', &block).count
      end

      def arrange_push_needing_housekeeping
        allow(subject).to receive_messages(try_obtain_lease: :the_uuid, lease_key: :the_lease_key)
        allow(Gitlab::CurrentSettings).to receive(:housekeeping_incremental_repack_period).and_return(10)
        allow(resource.git_garbage_collect_worker_klass).to receive(:perform_async)
        9.times { resource.increment_pushes_since_gc }
      end

      it 'touches the counter key once for a push that does not need housekeeping' do
        commands = counter_commands do
          subject.increment!
          subject.execute if subject.needed?
        end

        expect(commands).to eq(1)
        expect(resource.pushes_since_gc).to eq(1)
      end

      it 'touches the counter key once for a push that needs housekeeping' do
        arrange_push_needing_housekeeping

        commands = counter_commands do
          subject.increment!
          subject.execute if subject.needed?
        end

        expect(commands).to eq(1)
        expect(resource.pushes_since_gc).to eq(10)
      end

      it 'reads the feature flag once per push' do
        allow(Feature).to receive(:enabled?).and_call_original

        subject.increment!
        subject.execute if subject.needed?

        expect(Feature).to have_received(:enabled?)
          .with(:housekeeping_reuse_incremented_push_count, feature_flag_actor).once
      end

      it 'takes the counter key once when the flag is enabled for the actor only' do
        stub_feature_flags(housekeeping_reuse_incremented_push_count: feature_flag_actor)

        commands = counter_commands do
          subject.increment!
          subject.execute if subject.needed?
        end

        expect(commands).to eq(1)
        expect(resource.pushes_since_gc).to eq(1)
      end

      context 'when the housekeeping_reuse_incremented_push_count flag is disabled' do
        before do
          stub_feature_flags(housekeeping_reuse_incremented_push_count: false)
        end

        it 'reads the counter key back for a push that does not need housekeeping' do
          commands = counter_commands do
            subject.increment!
            subject.execute if subject.needed?
          end

          expect(commands).to eq(4)
          expect(resource.pushes_since_gc).to eq(1)
        end

        it 'reads the counter key back for a push that needs housekeeping' do
          arrange_push_needing_housekeeping

          commands = counter_commands do
            subject.increment!
            subject.execute if subject.needed?
          end

          expect(commands).to eq(6)
          expect(resource.pushes_since_gc).to eq(10)
        end
      end
    end

    describe 'task selection with a service instance per push' do
      shared_examples 'the same task at every period boundary' do
        it 'picks the same task at every period boundary' do
          allow(Gitlab::CurrentSettings).to receive(:housekeeping_incremental_repack_period).and_return(10)

          tasks = []
          allow(resource.git_garbage_collect_worker_klass).to receive(:perform_async) do |_id, task, *|
            tasks << [resource.pushes_since_gc, task]
          end

          201.times do
            service = described_class.new(resource)
            allow(service).to receive_messages(try_obtain_lease: :the_uuid, lease_key: :the_lease_key)

            service.increment!
            service.execute if service.needed?
          end

          expect(tasks).to eq((10..190).step(10).map { |push| [push, :incremental_repack] } + [[200, :gc]])
          expect(resource.pushes_since_gc).to eq(1)
        end
      end

      it_behaves_like 'the same task at every period boundary'

      context 'when the housekeeping_reuse_incremented_push_count flag is disabled' do
        before do
          stub_feature_flags(housekeeping_reuse_incremented_push_count: false)
        end

        it_behaves_like 'the same task at every period boundary'
      end
    end
  end
end
