# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Graphql::Subscriptions::Envelope, feature_category: :api do
  def envelope(locations, payload: locations.keys)
    described_class.new(
      described_class::KEY_WAL_LOCATIONS => locations,
      described_class::KEY_PAYLOAD => payload
    )
  end

  describe '.wrap' do
    it 'puts the payload next to the WAL locations and the correlation ID', :aggregate_failures do
      wrapped = described_class.wrap({ 'a' => 1 }, wal_locations: { 'main' => '0/1' }, correlation_id: 'abc')

      expect(wrapped.payload).to eq('a' => 1)
      expect(wrapped.wal_locations).to eq('main' => '0/1')
      expect(wrapped.correlation_id).to eq('abc')
    end
  end

  describe '.parse' do
    it 'reads an envelope without resolving its payload', :aggregate_failures do
      raw = Gitlab::Json.dump(envelope({ 'main' => '0/1' }, payload: { '__gid__' => 'g' }).to_h)
      parsed = described_class.parse(raw)

      expect(parsed).to be_readable
      expect(parsed.record_id).to eq('g')
    end

    it 'is nil for a message that is not an envelope' do
      expect(described_class.parse(Gitlab::Json.dump('__gid__' => 'g'))).to be_nil
    end

    it 'is an unreadable envelope for a message that cannot be parsed', :aggregate_failures do
      parsed = described_class.parse('{"wal_locations":')

      expect(parsed).not_to be_readable
      expect(parsed.wal_locations).to be_nil
    end
  end

  describe '.merge' do
    it 'merges two envelopes' do
      expect(described_class.merge(envelope({ 'main' => '0/1' }), envelope({ 'main' => '0/2' })).wal_locations)
        .to eq('main' => '0/2')
    end

    it 'rejects a raw hash, which would merge without the WAL location rules' do
      expect { described_class.merge(envelope({}).to_h, envelope({})) }.to raise_error(ArgumentError)
    end
  end

  describe '#record_id' do
    it 'is the global ID of a payload that is one record' do
      expect(envelope({}, payload: { '__gid__' => 'gid-1' }).record_id).to eq('gid-1')
    end

    it 'is nil for a payload with more than the global ID' do
      expect(envelope({}, payload: { '__gid__' => 'gid-1', 'action' => 'updated' }).record_id).to be_nil
    end

    it 'is nil for a payload that is not one record' do
      expect(envelope({}, payload: { 'work_item_id' => 1 }).record_id).to be_nil
    end

    it 'is nil for a payload that is not a hash' do
      expect(envelope({}, payload: 'pipeline-1').record_id).to be_nil
    end
  end

  describe '#merge' do
    it 'keeps the newer payload with the newest location of each database' do
      older = envelope({ 'main' => 'A/0', 'ci' => '0/5' })
      newer = envelope({ 'main' => '9/FFFFFFFF', 'sec' => '1/0' })

      expect(older.merge(newer).to_h).to eq(
        described_class::KEY_WAL_LOCATIONS => { 'main' => 'A/0', 'ci' => '0/5', 'sec' => '1/0' },
        described_class::KEY_PAYLOAD => %w[main sec]
      )
    end

    it 'has no locations when one is unreadable, so that the update reads from the primary', :aggregate_failures do
      readable = envelope({ 'main' => '0/1' })
      unreadable = envelope({ 'main' => 'junk' })

      expect(unreadable.merge(readable).wal_locations).to eq({})
      expect(readable.merge(unreadable).wal_locations).to eq({})
    end

    it 'has no locations when either update has none, so that the update reads from the primary' do
      located = envelope({ 'main' => '0/1' })

      expect(located.merge(envelope({})).wal_locations).to eq({})
      expect(envelope({}).merge(located).wal_locations).to eq({})
    end
  end
end
