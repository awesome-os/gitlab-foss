# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::CollaborativeEditing::DocumentStore, :clean_gitlab_redis_shared_state,
  feature_category: :wiki do
  let(:document_key) { 'wiki:Project:1:home' }

  subject(:store) { described_class.new(document_key) }

  before do
    store.open(version: 'version-one')
  end

  describe '#updates' do
    it 'is empty for an unknown document' do
      expect(store.updates).to eq([])
    end

    it 'returns appended updates in order' do
      store.append('first')
      store.append('second')

      expect(store.updates).to eq(%w[first second])
    end
  end

  describe '#append' do
    it 'sets an expiry so documents do not accumulate once editing stops' do
      store.append('update')

      ttl = Gitlab::Redis::SharedState.with { |redis| redis.ttl(updates_key) }

      expect(ttl).to be_positive
    end

    it 'refreshes the expiry on every write' do
      store.append('update')
      Gitlab::Redis::SharedState.with { |redis| redis.expire(updates_key, 5) }

      store.append('another update')

      ttl = Gitlab::Redis::SharedState.with { |redis| redis.ttl(updates_key) }

      expect(ttl).to be > 5
    end

    it 'expires the byte counter with the document', :aggregate_failures do
      store.append('update')

      expect(ttl_of(bytes_key)).to be_positive
      expiries = Gitlab::Redis::SharedState.with do |redis|
        redis.multi do |transaction|
          transaction.pexpiretime(updates_key)
          transaction.pexpiretime(bytes_key)
        end
      end

      expect(expiries.uniq.size).to eq(1)
      expect(ttl_of("collaborative_editing:{#{document_key}}:snapshot_bytes")).to be_positive
    end

    context 'when the byte budget is reached' do
      before do
        stub_const("#{described_class}::MAX_LOG_BYTES", 10)
        stub_const("#{described_class}::COMPACTION_BYTES", 5)
      end

      it 'requests compaction before exhausting the budget' do
        expect(store.append('12345')).to be_compact
      end

      it 'does not compact a large snapshot after each update', :aggregate_failures do
        stub_const("#{described_class}::MAX_LOG_BYTES", 100)
        stub_const("#{described_class}::COMPACTION_BYTES", 50)
        token = store.append('a' * 50).compaction_token
        store.replace('a' * 60, token)

        5.times { expect(store.append('b')).not_to be_compact }
      end

      it 'requests compaction once the log doubles its snapshot size', :aggregate_failures do
        stub_const("#{described_class}::MAX_LOG_BYTES", 100)
        stub_const("#{described_class}::COMPACTION_BYTES", 50)
        token = store.append('a' * 50).compaction_token
        store.replace('a' * 30, token)

        expect(store.append('b' * 29)).not_to be_compact
        expect(store.append('b')).to be_compact
      end

      it 'compacts large snapshots halfway through the remaining budget', :aggregate_failures do
        stub_const("#{described_class}::MAX_LOG_BYTES", 100)
        stub_const("#{described_class}::COMPACTION_BYTES", 50)
        token = store.append('a' * 50).compaction_token
        store.replace('a' * 60, token)

        expect(store.append('b' * 19)).not_to be_compact
        result = store.append('b')

        expect(result).not_to be_full
        expect(result).to be_compact
      end

      it 'does not compact repeatedly after replacing a large snapshot', :aggregate_failures do
        stub_const("#{described_class}::MAX_LOG_BYTES", 100)
        stub_const("#{described_class}::COMPACTION_BYTES", 50)
        token = store.append('a' * 50).compaction_token
        store.replace('a' * 80, token)
        token = store.append('b' * 10).compaction_token

        expect(token).to be_present
        expect(store.replace('a' * 85, token)).to eq(:replaced)
        expect(store.append('b')).not_to be_compact
      end

      it 'still compacts a full log when the snapshot fills the budget', :aggregate_failures do
        token = store.append('12345').compaction_token
        store.replace('1234567890', token)

        result = store.append('1')

        expect(result).to be_full
        expect(result).to be_compact
      end

      it 'uses the compaction floor for small snapshots', :aggregate_failures do
        token = store.append('12345').compaction_token
        store.replace('1', token)

        expect(store.append('234')).not_to be_compact
        expect(store.append('5')).to be_compact
      end

      it 'counts the suffix towards growth since the last snapshot', :aggregate_failures do
        stub_const("#{described_class}::MAX_LOG_BYTES", 100)
        stub_const("#{described_class}::COMPACTION_BYTES", 50)
        token = store.append('a' * 50).compaction_token
        store.append('b' * 20)
        store.replace('a' * 30, token)

        expect(store.append('c' * 9)).not_to be_compact
        expect(store.append('c')).to be_compact
      end

      it 'rejects an update that would exceed the budget', :aggregate_failures do
        store.append('12345678')

        expect(store.append('123')).to be_full
        expect(store.updates).to eq(['12345678'])
      end

      it 'allows a compacted document to accept further updates', :aggregate_failures do
        token = store.append('12345678').compaction_token

        expect(store.replace('1234', token)).to eq(:replaced)
        expect(store.append('123456')).not_to be_full
        expect(store.updates).to eq(%w[1234 123456])
      end

      it 'rejects an over-budget snapshot without preventing a valid retry', :aggregate_failures do
        token = store.append('12345678').compaction_token

        expect(store.replace('12345678901', token)).to eq(:full)
        expect(store.updates).to eq(['12345678'])
        expect(store.append('123')).to be_full
        expect(store.append('1')).not_to be_full
        expect(store.replace('small', token)).to eq(:replaced)
        expect(store.updates).to eq(%w[small 1])
      end

      it 'includes updates added after the compaction claim in the byte budget', :aggregate_failures do
        token = store.append('12345').compaction_token
        store.append('1234')

        expect(store.replace('1234567', token)).to eq(:full)
        expect(store.updates).to eq(%w[12345 1234])
      end

      it 'keeps the accepted budget, baseline and expiries on a failed compaction', :aggregate_failures do
        stub_const("#{described_class}::COMPACTION_THRESHOLD", 2)
        token = store.append('12345').compaction_token
        store.replace('1234', token)
        token = store.append('1').compaction_token
        store.append('234')
        baseline_key = "collaborative_editing:{#{document_key}}:snapshot_bytes"
        claim_key = "collaborative_editing:{#{document_key}}:compaction"
        keys = [updates_key, bytes_key, baseline_key, claim_key]
        Gitlab::Redis::SharedState.with { |redis| keys.each { |key| redis.expire(key, 10) } }

        expect(store.replace('12345678', token)).to eq(:full)

        expect(store.updates).to eq(%w[1234 1 234])
        expect(Gitlab::Redis::SharedState.with { |redis| redis.mget(bytes_key, baseline_key) }).to eq(%w[8 4])
        keys.each { |key| expect(ttl_of(key)).to be_between(1, 10) }
      end

      it 'accepts a snapshot and suffix at the exact byte budget', :aggregate_failures do
        token = store.append('12345').compaction_token
        store.append('1234')

        expect(store.replace('123456', token)).to eq(:replaced)
        expect(store.updates).to eq(%w[123456 1234])
        expect(store.append('x')).to be_full
      end

      it 'lets another compactor recover a full log after a rejected claim expires', :aggregate_failures do
        token = store.append('12345').compaction_token
        store.append('67890')
        expect(store.replace('12345678', token)).to eq(:full)
        expect(store.append('x')).not_to be_compact
        expire_compaction_claim
        other_store = described_class.new(document_key)
        other_store.open(version: 'version-one')
        result = other_store.append('x')

        expect(result).to be_full
        expect(result).to be_compact
        expect(other_store.replace('small', token)).to eq(:invalid_claim)
        expect(other_store.replace('small', result.compaction_token)).to eq(:replaced)
        expect(store.append('x')).not_to be_full
        expect(store.updates).to eq(%w[small x])
      end
    end

    it 'refuses an update that is not a String' do
      expect { store.append(%w[a b]) }.to raise_error(ArgumentError)
    end

    it 'asks for no compaction while below the threshold', :aggregate_failures do
      result = store.append('update')

      expect(result).not_to be_full
      expect(result).not_to be_compact
    end

    it 'asks for compaction once the log reaches the threshold', :aggregate_failures do
      stub_const("#{described_class}::COMPACTION_THRESHOLD", 2)

      expect(store.append('first')).not_to be_compact
      expect(store.append('second')).to be_compact
    end

    it 'asks one caller only while the log stays uncompacted', :aggregate_failures do
      stub_const("#{described_class}::COMPACTION_THRESHOLD", 2)

      store.append('first')

      expect(store.append('second')).to be_compact
      expect(store.append('third')).not_to be_compact
      expect(store.append('fourth')).not_to be_compact
    end

    it 'asks again once the log has been compacted' do
      stub_const("#{described_class}::COMPACTION_THRESHOLD", 2)

      store.append('first')
      token = store.append('second').compaction_token

      store.replace('snapshot', token)

      expect(store.append('third')).to be_compact
    end

    it 'scopes the compaction claim to a single document' do
      stub_const("#{described_class}::COMPACTION_THRESHOLD", 1)

      store.append('first')

      other_store = described_class.new('wiki:Project:1:other')
      other_store.open(version: 'version-one')

      expect(other_store.append('first')).to be_compact
    end

    context 'when the log is at its ceiling' do
      before do
        stub_const("#{described_class}::COMPACTION_THRESHOLD", 2)
        stub_const("#{described_class}::MAX_LOG_LENGTH", 2)
      end

      it 'reports the document as full' do
        store.append('first')
        store.append('second')

        expect(store.append('third')).to be_full
      end

      it 'does not store the rejected update' do
        store.append('first')
        store.append('second')

        store.append('third')

        expect(store.updates).to eq(%w[first second])
      end

      it 'does not extend the life of a log it is refusing to write to' do
        store.append('first')
        store.append('second')
        Gitlab::Redis::SharedState.with { |redis| redis.expire(updates_key, 60) }

        store.append('third')

        ttl = Gitlab::Redis::SharedState.with { |redis| redis.ttl(updates_key) }

        expect(ttl).to be <= 60
      end

      it 'accepts updates again once the log has been compacted', :aggregate_failures do
        store.append('first')
        token = store.append('second').compaction_token

        store.replace('snapshot', token)

        expect(store.append('third')).not_to be_full
        expect(store.updates).to eq(%w[snapshot third])
      end

      context 'and the compactor never delivered a snapshot' do
        it 'asks a later caller to compact', :aggregate_failures do
          store.append('first')
          store.append('second')
          expire_compaction_claim

          result = store.append('third')

          expect(result).to be_full
          expect(result).to be_compact
        end

        it 'recovers the document when that caller compacts', :aggregate_failures do
          store.append('first')
          store.append('second')
          expire_compaction_claim

          token = store.append('third').compaction_token
          expect(store.replace('snapshot', token)).to eq(:replaced)

          expect(store.append('fourth')).not_to be_full
          expect(store.updates).to eq(%w[snapshot fourth])
        end

        it 'still asks only one caller at a time', :aggregate_failures do
          store.append('first')
          store.append('second')
          expire_compaction_claim

          expect(store.append('third')).to be_compact
          expect(store.append('fourth')).not_to be_compact
        end
      end
    end
  end

  describe '#replace' do
    let(:token) do
      stub_const("#{described_class}::COMPACTION_THRESHOLD", 2)

      store.append('first')
      store.append('second').compaction_token
    end

    it 'swaps the claimed log for the snapshot' do
      store.replace('snapshot', token)

      expect(store.updates).to eq(['snapshot'])
    end

    it 'sets an expiry on the compacted log' do
      store.replace('snapshot', token)

      ttl = Gitlab::Redis::SharedState.with { |redis| redis.ttl(updates_key) }

      expect(ttl).to be_positive
    end

    it 'refreshes the snapshot baseline expiry with the log', :aggregate_failures do
      store.replace('snapshot', token)
      key = "collaborative_editing:{#{document_key}}:snapshot_bytes"

      expect(ttl_of(key)).to be_positive
      Gitlab::Redis::SharedState.with { |redis| redis.expire(key, 5) }

      store.append('third')

      expect(ttl_of(key)).to be > 5
      expiries = Gitlab::Redis::SharedState.with do |redis|
        redis.multi do |transaction|
          transaction.pexpiretime(updates_key)
          transaction.pexpiretime(bytes_key)
          transaction.pexpiretime(key)
        end
      end

      expect(expiries.uniq.size).to eq(1)
    end

    it 'expires the byte counters with the compacted log', :aggregate_failures do
      store.replace('snapshot', token)
      key = "collaborative_editing:{#{document_key}}:snapshot_bytes"

      expect(ttl_of(bytes_key)).to be_positive
      expect(ttl_of(key)).to be_positive
      expiries = Gitlab::Redis::SharedState.with do |redis|
        redis.multi do |transaction|
          transaction.pexpiretime(updates_key)
          transaction.pexpiretime(bytes_key)
          transaction.pexpiretime(key)
        end
      end

      expect(expiries.uniq.size).to eq(1)
    end

    it 'keeps updates appended while the snapshot was being built', :aggregate_failures do
      claim = token
      store.append('third')

      expect(store.replace('snapshot', claim)).to eq(:replaced)
      expect(store.updates).to eq(%w[snapshot third])
    end

    context 'without a valid claim' do
      it 'refuses a token that does not match the outstanding claim', :aggregate_failures do
        token

        expect(store.replace('snapshot', 'not-the-token')).to eq(:invalid_claim)
        expect(store.updates).to eq(%w[first second])
      end

      it 'refuses an empty token', :aggregate_failures do
        token

        expect(store.replace('snapshot', '')).to eq(:invalid_claim)
        expect(store.updates).to eq(%w[first second])
      end

      it 'refuses a token when no compaction was claimed', :aggregate_failures do
        store.append('only')

        expect(store.replace('snapshot', 'made-up')).to eq(:invalid_claim)
        expect(store.updates).to eq(['only'])
      end

      it 'refuses to reuse a token that has already compacted', :aggregate_failures do
        claim = token
        store.replace('snapshot', claim)
        store.append('third')

        expect(store.replace('second-snapshot', claim)).to eq(:invalid_claim)
        expect(store.updates).to eq(%w[snapshot third])
      end
    end

    context 'with arguments that break the contract' do
      [nil, { 'a' => 'b' }, 1, :sym, %w[a b]].each do |bad|
        it "refuses a #{bad.class} token, leaving the log intact", :aggregate_failures do
          claim = token

          expect { store.replace('snapshot', bad) }.to raise_error(ArgumentError)
          expect(store.updates).to eq(%w[first second])
          expect(ttl_of(updates_key)).to be_positive
          expect(store.replace('snapshot', claim)).to eq(:replaced)
        end
      end

      it 'refuses a snapshot that is not a String', :aggregate_failures do
        token

        expect { store.replace(%w[a b], token) }.to raise_error(ArgumentError)
        expect(store.updates).to eq(%w[first second])
      end
    end
  end

  describe '#open' do
    it 'requires a nonempty page version', :aggregate_failures do
      [nil, ''].each { |version| expect { store.open(version: version) }.to raise_error(ArgumentError) }
      expect(store.claim_save(session_id: nil, save_id: 'save', user_id: 1)).to be(false)
    end

    it 'replaces outside versions but waits for an in-flight save', :aggregate_failures do
      session = store.open(version: 'version-one')
      marker = { session_id: session.session_id, save_id: 'save', user_id: 1 }
      expect(store.claim_save(**marker)).to be(true)
      expect(store.claim_save(**marker)).to be(false)
      save_key = "collaborative_editing:{#{document_key}}:save"
      Gitlab::Redis::SharedState.with { |redis| redis.expire(save_key, 5) }
      store.touch(session_id: session.session_id, version: 'version-one')
      expect(ttl_of(save_key)).to be_between(1, 5)
      expect(store.confirm_save(**marker, version: 'wrong')).to be(false)
      expect(store.confirm_save(**marker, version: 'version-one')).to be(true)
      expect(ttl_of(save_key)).to be > 5
      expect(store.open(version: 'version-two').busy).to be(true)
      expect(store.touch(session_id: session.session_id, version: 'version-two')).to eq(:busy)
      store.append('later', session_id: session.session_id)
      expect(store.advance_version(**marker, previous_version: 'version-one', version: 'version-two')).to be(true)
      expect(store.read_session(session_id: session.session_id)).to eq([['later'], 'version-two'])
      expect(store.open(version: 'version-two').session_id).to eq(session.session_id)
      expect(store.touch(session_id: session.session_id, version: 'outside')).to eq(:page_changed)
      expect(store.open(version: 'outside').session_id).not_to eq(session.session_id)
    end

    it 'does not wait for a save claim that has not been confirmed', :aggregate_failures do
      session = store.open(version: 'version-one')
      store.claim_save(session_id: session.session_id, save_id: 'save', user_id: 1)

      expect(store.touch(session_id: session.session_id, version: 'version-two')).to eq(:page_changed)
      replacement = store.open(version: 'version-two')
      expect(replacement.busy).to be(false)
      expect(replacement.session_id).not_to eq(session.session_id)
    end

    it 'only releases and advances its own save marker', :aggregate_failures do
      session = store.open(version: 'version-one')
      marker = { session_id: session.session_id, save_id: 'save', user_id: 1 }
      store.claim_save(**marker)
      [{ session_id: 'wrong' }, { save_id: 'wrong' }, { user_id: 2 }].each do |wrong|
        expect(store.advance_version(**marker.merge(wrong), previous_version: 'version-one',
          version: 'new')).to be(false)
        expect(store.release_save(**marker.merge(wrong))).to be(false)
      end
      expect(store.advance_version(**marker, previous_version: 'wrong', version: 'new')).to be(false)
      expect(store.release_save(**marker)).to be(true)
      expect(store.confirm_save(**marker, version: 'version-one')).to be(false)
    end

    it 'elects one seed after admitting concurrent openers', :aggregate_failures do
      sessions = Array.new(2) do
        Thread.new { described_class.new('concurrent-open').open(version: 'version-one') }
      end.map(&:value)

      expect(sessions.map(&:session_id).uniq.size).to eq(1)
      decisions = sessions.map do |session|
        described_class.new('concurrent-open')
          .read_session(session_id: session.session_id, client_version: 'version-one').last
      end
      expect(decisions.count(true)).to eq(1)
    end

    it 'keeps the generation and seed decision for an accepted log', :aggregate_failures do
      initial = store.open(version: 'version-one')
      store.append('accepted')
      joined = described_class.new(document_key).open(version: 'version-one')

      expect(joined.session_id).to eq(initial.session_id)
      expect(store.read_session(session_id: joined.session_id)).to eq([['accepted'], 'version-one'])
      expect(store.read_session(session_id: joined.session_id, client_version: 'version-one').last).to be(false)
    end

    it 'replaces a generation whose accepted log disappeared', :aggregate_failures do
      initial = store.open(version: 'version-one')
      store.append('accepted')
      Gitlab::Redis::SharedState.with { |redis| redis.del(updates_key) }

      expect(store.touch(session_id: initial.session_id)).to be(false)
      replacement = described_class.new(document_key).open(version: 'version-one')

      expect(replacement.session_id).not_to eq(initial.session_id)
      expect(store.read_session(session_id: replacement.session_id)).to eq([[], 'version-one'])
      expect(store.read_session(session_id: replacement.session_id, client_version: 'version-one').last).to be(true)
      expect(store.append('stale', session_id: initial.session_id)).to be_invalid_session
      expect(store.replace('stale', 'claim', session_id: initial.session_id)).to eq(:invalid_session)
      expect(store.updates).to be_empty
    end

    it 'succeeds for the first caller only', :aggregate_failures do
      other = described_class.new('unopened')

      session = other.open(version: 'version-one')
      expect(other.read_session(session_id: session.session_id, client_version: 'version-one').last).to be(true)
      expect(other.read_session(session_id: session.session_id, client_version: 'version-one').last).to be(false)
    end

    it 'scopes the claim to a single document' do
      other = described_class.new('wiki:Project:1:other')
      session = other.open(version: 'version-one')
      expect(other.read_session(session_id: session.session_id, client_version: 'version-one').last).to be(true)
    end
  end

  describe '#touch' do
    [nil, ''].each do |session_id|
      it "rejects #{session_id.inspect} generations without accessing Redis", :aggregate_failures do
        expect(store).not_to receive(:with_redis)

        expect(store.touch(session_id: session_id)).to be(false)
        expect(store.append('delta', session_id: session_id)).to be_invalid_session
        expect(store.replace('snapshot', 'claim', session_id: session_id)).to eq(:invalid_session)
      end
    end

    %w[session bytes snapshot_bytes updates].each do |suffix|
      it "rejects writes after the accepted #{suffix} key expires", :aggregate_failures do
        session = store.open(version: 'version-one')
        stub_const("#{described_class}::COMPACTION_THRESHOLD", 1)
        token = store.append('accepted').compaction_token
        key = "collaborative_editing:{#{document_key}}:#{suffix}"
        Gitlab::Redis::SharedState.with { |redis| redis.del(key) }

        expect(store.touch(session_id: session.session_id)).to be(false)
        expect(store.append('orphan')).to be_invalid_session
        expect(store.replace('orphan', token)).to eq(:invalid_session)
        expect(ttl_of(key)).to eq(-2)
      end
    end

    it 'keeps an unseeded session alive without prolonging its seed claim', :aggregate_failures do
      session = store.open(version: 'version-one')
      store.read_session(session_id: session.session_id, client_version: 'version-one')
      keys = [bytes_key, "collaborative_editing:{#{document_key}}:snapshot_bytes",
        "collaborative_editing:{#{document_key}}:session"]
      seed_key = "collaborative_editing:{#{document_key}}:seed"
      Gitlab::Redis::SharedState.with do |redis|
        keys.each { |key| redis.expire(key, 5) }
        redis.expire(seed_key, 5)
      end

      expect(store.touch(session_id: session.session_id)).to be(true)
      keys.each { |key| expect(ttl_of(key)).to be > 5 }
      expect(ttl_of(seed_key)).to be_between(1, 5)
      expect(store.updates).to be_empty
    end

    it 'refreshes persistent state together but not the compaction lease', :aggregate_failures do
      stub_const("#{described_class}::COMPACTION_THRESHOLD", 1)
      session = store.open(version: 'version-one')
      token = store.append('initial').compaction_token
      store.replace('snapshot', token)
      store.append('delta')
      keys = [updates_key, bytes_key, "collaborative_editing:{#{document_key}}:snapshot_bytes",
        "collaborative_editing:{#{document_key}}:session"]
      claim_key = "collaborative_editing:{#{document_key}}:compaction"
      Gitlab::Redis::SharedState.with do |redis|
        (keys + [claim_key]).each { |key| redis.expire(key, 5) }
      end

      expect(store.touch(session_id: session.session_id)).to be(true)
      expiries = Gitlab::Redis::SharedState.with { |redis| keys.map { |key| redis.pexpiretime(key) } }

      expect(expiries.uniq.size).to eq(1)
      expect(ttl_of(updates_key)).to be > 5
      expect(ttl_of(claim_key)).to be_between(1, 5)
      expect(store.updates).to eq(%w[snapshot delta])
    end

    it 'does not let an ordinary append open a session', :aggregate_failures do
      unopened = described_class.new('never-opened')

      expect(unopened.append('delta', session_id: 'invented')).to be_invalid_session
      expect(unopened.updates).to be_empty
    end
  end

  describe '#read_session' do
    it 'returns the current log only for the matching generation', :aggregate_failures do
      session = store.open(version: 'version-one')
      store.append('accepted')

      expect(store.read_session(session_id: session.session_id)).to eq([['accepted'], 'version-one'])
      expect(store.read_session(session_id: 'stale')).to be_nil
      expect(store.read_session(session_id: nil)).to be_nil
    end

    it 'does not reopen missing state during the final replay', :aggregate_failures do
      session = store.open(version: 'version-one')
      store.append('accepted')
      Gitlab::Redis::SharedState.with { |redis| redis.del(updates_key) }

      expect(store.read_session(session_id: session.session_id)).to be_nil
      expect(ttl_of(updates_key)).to eq(-2)
    end
  end

  def updates_key
    "collaborative_editing:{#{document_key}}:updates"
  end

  def bytes_key
    "collaborative_editing:{#{document_key}}:bytes"
  end

  def ttl_of(key)
    Gitlab::Redis::SharedState.with { |redis| redis.ttl(key) }
  end

  def expire_compaction_claim
    Gitlab::Redis::SharedState.with do |redis|
      redis.del("collaborative_editing:{#{document_key}}:compaction")
    end
  end
end
