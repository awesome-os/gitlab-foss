# frozen_string_literal: true

require 'fast_spec_helper'

RSpec.describe Gitlab::Graphql::Subscriptions::Coalescer, feature_category: :api do
  let(:timers) { [] }
  let(:scheduler) { ->(delay, &block) { timers << { delay: delay, block: block } } }
  let(:merge) { ->(older, newer) { "#{older}+#{newer}" } }
  let(:dispatched) { [] }
  let(:dispatch) { ->(update) { dispatched << update } }

  subject(:coalescer) { described_class.new(merge: merge, scheduler: scheduler) }

  def key(record = 'pipeline-1', topic: 'topic-1')
    described_class::Key.new(topic: topic, fingerprint: 'fingerprint', record: record)
  end

  def submit(update, record: 'pipeline-1', topic: 'topic-1', &block)
    coalescer.submit(key(record, topic: topic), update, window: 2, &block || dispatch)
  end

  def end_window
    timers.shift.fetch(:block).call
  end

  it 'runs the first update at once and opens a window', :aggregate_failures do
    expect(submit('a')).to eq(:run)
    expect(timers).to contain_exactly(a_hash_including(delay: 2))
    expect(coalescer.size).to eq(1)
  end

  it 'merges the updates of a window and runs them once when it ends', :aggregate_failures do
    submit('a')

    expect(submit('b')).to eq(:deferred)
    expect(submit('c')).to eq(:deferred)
    expect(dispatched).to be_empty

    end_window

    expect(dispatched).to eq(['b+c'])
  end

  it 'merges only the updates that are still pending into the next window', :aggregate_failures do
    submit('a')
    submit('b')
    end_window

    expect(submit('c')).to eq(:deferred)

    end_window

    expect(dispatched).to eq(%w[b c])
  end

  it 'forgets a key when its window ends with nothing pending', :aggregate_failures do
    submit('a')
    end_window

    expect(coalescer.size).to eq(0)
    expect(timers).to be_empty
    expect(submit('b')).to eq(:run)
  end

  it 'keeps keys apart' do
    submit('a', record: 'pipeline-1')

    expect(submit('b', record: 'pipeline-2')).to eq(:run)
  end

  it 'frees a slot on a topic when one of its keys is forgotten', :aggregate_failures do
    stub_const("#{described_class}::MAX_KEYS_PER_TOPIC", 2)
    submit('a', record: 'pipeline-1')
    submit('b', record: 'pipeline-2')
    end_window

    expect(submit('c', record: 'pipeline-3')).to eq(:run)
    expect(submit('d', record: 'pipeline-4')).to eq(:overflow)
  end

  it 'reports a deferred update that fails and opens the next window', :aggregate_failures do
    error = RuntimeError.new('boom')
    failing = ->(_update) { raise error }
    submit('a', &failing)
    submit('b', &failing)

    expect(Gitlab::ErrorTracking).to receive(:track_exception).with(error)

    expect { end_window }.not_to raise_error
    expect(timers.size).to eq(1)

    end_window

    expect(coalescer.size).to eq(0)
  end

  context 'when the scheduler fails' do
    let(:error) { RuntimeError.new('executor is shut down') }
    let(:failing_call) { 1 }
    let(:failing_once) do
      calls = 0
      ->(delay, &block) { (calls += 1) == failing_call ? raise(error) : scheduler.call(delay, &block) }
    end

    subject(:coalescer) { described_class.new(merge: merge, scheduler: failing_once) }

    it 'forgets the key when it cannot open the window', :aggregate_failures do
      expect { submit('a') }.to raise_error(error)
      expect(coalescer.size).to eq(0)
      expect(submit('b')).to eq(:run)
    end

    context 'when it cannot open the next window' do
      let(:failing_call) { 2 }

      it 'forgets the key and reports the error', :aggregate_failures do
        submit('a')
        submit('b')

        expect(Gitlab::ErrorTracking).to receive(:track_exception).with(error)

        expect { end_window }.not_to raise_error
        expect(dispatched).to eq(['b'])
        expect(coalescer.size).to eq(0)
      end
    end
  end

  context 'when a key cap is reached' do
    it 'runs updates for new keys at once on a full topic', :aggregate_failures do
      stub_const("#{described_class}::MAX_KEYS_PER_TOPIC", 1)
      submit('a', record: 'pipeline-1')

      expect(submit('b', record: 'pipeline-2')).to eq(:overflow)
      expect(submit('c', record: 'pipeline-3', topic: 'topic-2')).to eq(:run)
      expect(coalescer.size).to eq(2)
    end

    it 'runs updates for new keys at once on a full process' do
      stub_const("#{described_class}::MAX_KEYS", 1)
      submit('a', record: 'pipeline-1')

      expect(submit('b', record: 'pipeline-2', topic: 'topic-2')).to eq(:overflow)
    end

    it 'still merges the updates of keys it already has' do
      stub_const("#{described_class}::MAX_KEYS", 1)
      submit('a')

      expect(submit('b')).to eq(:deferred)
    end
  end
end
