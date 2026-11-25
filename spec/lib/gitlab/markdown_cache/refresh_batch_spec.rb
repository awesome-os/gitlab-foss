# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::MarkdownCache::RefreshBatch, feature_category: :markdown do
  let(:worker) { Gitlab::MarkdownCache::RefreshWorker }

  before do
    allow(worker).to receive(:perform_async)
  end

  def note(id)
    build_stubbed(:note, id: id)
  end

  describe '.add' do
    context 'when outside a within block' do
      it 'enqueues the record at once' do
        described_class.add(note(1))

        expect(worker).to have_received(:perform_async).with('Note', [1])
      end
    end

    context 'when inside a within block' do
      it 'enqueues nothing until the block ends' do
        described_class.within do
          described_class.add(note(1))

          expect(worker).not_to have_received(:perform_async)
        end

        expect(worker).to have_received(:perform_async).with('Note', [1])
      end
    end
  end

  describe '.within' do
    it 'returns the block value' do
      expect(described_class.within { :value }).to eq(:value)
    end

    it 'enqueues one job per class' do
      described_class.within do
        described_class.add(note(1))
        described_class.add(build_stubbed(:issue, id: 3))
        described_class.add(note(2))
      end

      expect(worker).to have_received(:perform_async).with('Note', [1, 2]).once
      expect(worker).to have_received(:perform_async).with('Issue', [3]).once
    end

    it 'enqueues each record once' do
      described_class.within do
        2.times { described_class.add(note(1)) }
      end

      expect(worker).to have_received(:perform_async).with('Note', [1]).once
    end

    it 'splits a class into jobs of at most BATCH_SIZE records' do
      stub_const("#{described_class}::BATCH_SIZE", 2)

      described_class.within do
        (1..3).each { |id| described_class.add(note(id)) }
      end

      expect(worker).to have_received(:perform_async).with('Note', [1, 2]).ordered
      expect(worker).to have_received(:perform_async).with('Note', [3]).ordered
    end

    it 'enqueues in the application context the records were added in' do
      caller_ids = []
      allow(worker).to receive(:perform_async) { caller_ids << Gitlab::ApplicationContext.current['meta.caller_id'] }

      described_class.within do
        Gitlab::ApplicationContext.with_context(caller_id: 'Projects::NotesController#index') do
          described_class.add(note(1))
        end
      end

      expect(caller_ids).to eq(['Projects::NotesController#index'])
    end

    it 'enqueues nothing when no records were added' do
      described_class.within { nil }

      expect(worker).not_to have_received(:perform_async)
    end

    context 'when the block raises' do
      it 'still enqueues the records added' do
        expect do
          described_class.within do
            described_class.add(note(1))
            raise ArgumentError
          end
        end.to raise_error(ArgumentError)

        expect(worker).to have_received(:perform_async).with('Note', [1])
      end
    end

    context 'when nested' do
      it 'enqueues everything once, at the end of the outer block' do
        described_class.within do
          described_class.add(note(1))
          described_class.within { described_class.add(note(2)) }

          expect(worker).not_to have_received(:perform_async)
        end

        expect(worker).to have_received(:perform_async).with('Note', [1, 2]).once
      end
    end

    context 'when ActionController::Live replaces and clears the execution state during the block' do
      it 'still enqueues the records added before' do
        described_class.within do
          described_class.add(note(1))

          if Gitlab.next_rails?
            ActiveSupport::IsolatedExecutionState.share_with(Thread.current) do
              ActiveSupport::IsolatedExecutionState.clear
            end
          else
            ActiveSupport::IsolatedExecutionState.share_with(Thread.current)
            ActiveSupport::IsolatedExecutionState.clear
          end
        end

        expect(worker).to have_received(:perform_async).with('Note', [1])
      end
    end
  end

  describe 'streaming controllers' do
    it 'do not share the pending batch with their streaming thread' do
      expect(Projects::CompareDiffsStreamController.live_streaming_excluded_keys).to include(described_class::STATE_KEY)
    end

    context 'when the block has ended' do
      it 'enqueues later records at once' do
        described_class.within { described_class.add(note(1)) }
        described_class.add(note(2))

        expect(worker).to have_received(:perform_async).with('Note', [2])
      end
    end
  end
end
