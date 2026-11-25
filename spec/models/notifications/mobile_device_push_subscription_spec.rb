# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Notifications::MobileDevicePushSubscription, feature_category: :notifications do
  describe 'associations' do
    it { is_expected.to belong_to(:user) }
  end

  describe 'validations' do
    subject { build(:mobile_device_push_subscription) }

    it { is_expected.to be_valid }
    it { is_expected.to validate_presence_of(:device_token) }
    it { is_expected.to allow_value(SecureRandom.hex(32)).for(:device_token) }
    it { is_expected.to allow_value('A' * 16).for(:device_token) }
    it { is_expected.not_to allow_value('not-a-hex-token!').for(:device_token) }
    it { is_expected.not_to allow_value('abcdef').for(:device_token) }
    it { is_expected.not_to allow_value('a' * 201).for(:device_token) }
    it { is_expected.to allow_value(nil).for(:content_key) }
    it { is_expected.not_to allow_value('').for(:content_key) }
    it { is_expected.to allow_value(Base64.strict_encode64(SecureRandom.random_bytes(32))).for(:content_key) }
    it { is_expected.not_to allow_value(Base64.strict_encode64(SecureRandom.random_bytes(16))).for(:content_key) }
    it { is_expected.not_to allow_value('not base64!').for(:content_key) }
    it { is_expected.not_to allow_value('a' * 65).for(:content_key) }

    describe 'subscriptions cap per user' do
      let_it_be(:user) { create(:user) }

      it 'rejects new subscriptions once the user reached the cap' do
        create(:mobile_device_push_subscription, user: user)
        stub_const("#{described_class}::MAX_SUBSCRIPTIONS_PER_USER", 1)

        subscription = build(:mobile_device_push_subscription, user: user)

        expect(subscription).not_to be_valid
        expect(subscription.errors[:base])
          .to include('cannot have more than 1 push subscriptions per user')
      end

      it 'does not apply the cap when updating an existing subscription' do
        subscription = create(:mobile_device_push_subscription, user: user)
        stub_const("#{described_class}::MAX_SUBSCRIPTIONS_PER_USER", 1)

        subscription.last_seen_at = Time.current

        expect(subscription).to be_valid
      end
    end
  end

  describe 'enums' do
    it { is_expected.to define_enum_for(:platform).with_values(ios: 0, macos: 1) }
    it { is_expected.to define_enum_for(:apns_environment).with_values(production: 0, sandbox: 1).with_prefix(:apns) }
    it { is_expected.to define_enum_for(:payload_mode).with_values(full: 0, id_only: 1).with_suffix(:payload) }
  end

  describe '.stale' do
    let_it_be(:user) { create(:user) }

    it 'returns subscriptions last seen before the cutoff' do
      stale = create(:mobile_device_push_subscription, user: user, last_seen_at: 91.days.ago)
      create(:mobile_device_push_subscription, user: user, last_seen_at: 89.days.ago)
      create(:mobile_device_push_subscription, user: user)

      expect(described_class.stale(90.days.ago)).to contain_exactly(stale)
    end

    it 'fills last_seen_at from the database default when not set explicitly' do
      subscription = create(:mobile_device_push_subscription, user: user)

      expect(subscription.reload.last_seen_at).to be_present
    end
  end

  describe '.subscribed_user_ids' do
    let_it_be(:user) { create(:user) }
    let_it_be(:unsubscribed_user) { create(:user) }

    it 'returns the distinct given user ids that have a subscription' do
      create_list(:mobile_device_push_subscription, 2, user: user)

      ids = described_class.subscribed_user_ids([user.id, unsubscribed_user.id, non_existing_record_id])

      expect(ids).to contain_exactly(user.id)
    end

    it 'returns an empty array when no given user has a subscription' do
      expect(described_class.subscribed_user_ids([unsubscribed_user.id])).to be_empty
    end
  end

  describe 'device token encryption' do
    let(:token) { SecureRandom.hex(32) }

    # Aliased so the raw jsonb text comes back as is: `pick` runs a column
    # named like an attribute back through that attribute's type, which here
    # would decrypt it.
    def stored_ciphertext(subscription)
      described_class.where(id: subscription.id).pick(Arel.sql('device_token::text AS raw_ciphertext'))
    end

    it 'stores the token encrypted and decrypts it transparently' do
      subscription = create(:mobile_device_push_subscription, device_token: token)

      expect(subscription.reload.device_token).to eq(token)
      expect(stored_ciphertext(subscription)).not_to include(token)
    end

    it 'does not produce deterministic ciphertext' do
      first = create(:mobile_device_push_subscription, device_token: token)
      second = create(:mobile_device_push_subscription, :sandbox, device_token: token)

      expect(stored_ciphertext(first)).not_to eq(stored_ciphertext(second))
    end

    it 'still decrypts ciphertext written with the deterministic scheme of earlier releases' do
      subscription = create(:mobile_device_push_subscription, device_token: token)
      deterministic_type = ActiveRecord::Encryption::EncryptedAttributeType.new(
        scheme: ActiveRecord::Encryption::Scheme.new(deterministic: true),
        cast_type: ActiveRecord::Type::Json.new
      )
      ciphertext = deterministic_type.serialize(token)

      expect(deterministic_type.serialize(token)).to eq(ciphertext)

      described_class.where(id: subscription.id)
        .update_all("device_token = #{described_class.connection.quote(ciphertext)}")

      expect(subscription.reload.device_token).to eq(token)
    end
  end

  describe 'device token digest' do
    let(:token) { SecureRandom.hex(32) }
    let(:digest) { Digest::SHA256.hexdigest(token) }

    it 'derives the digest from the normalized token on assignment' do
      subscription = build(:mobile_device_push_subscription, device_token: token.upcase)

      expect(subscription.device_token_digest).to eq(digest)
    end

    it 'clears the digest together with the token' do
      subscription = build(:mobile_device_push_subscription, device_token: token)

      subscription.device_token = nil

      expect(subscription.device_token_digest).to be_nil
    end

    it 'restores the digest on create when a caller cleared it' do
      subscription = build(:mobile_device_push_subscription, device_token: token)
      subscription.device_token_digest = nil

      subscription.save!

      expect(subscription.reload.device_token_digest).to eq(digest)
    end

    it 'finds rows by plaintext token regardless of casing' do
      subscription = create(:mobile_device_push_subscription, device_token: token)

      expect(described_class.with_device_token(token.upcase)).to contain_exactly(subscription)
    end

    it 'keeps one row per token and environment' do
      create(:mobile_device_push_subscription, device_token: token)

      expect { create(:mobile_device_push_subscription, device_token: token) }
        .to raise_error(ActiveRecord::RecordNotUnique)
      expect { create(:mobile_device_push_subscription, :sandbox, device_token: token) }
        .not_to raise_error
    end

    describe '.find_or_initialize_for_device' do
      it 'returns the registered row for the token and environment' do
        subscription = create(:mobile_device_push_subscription, device_token: token)
        create(:mobile_device_push_subscription, :sandbox, device_token: token)

        found = described_class.find_or_initialize_for_device(token.upcase, :production)

        expect(found).to eq(subscription)
        expect(found).not_to be_changed
      end

      it 'initializes an unregistered token with its digest' do
        subscription = described_class.find_or_initialize_for_device(token, :sandbox)

        expect(subscription).to be_new_record
        expect(subscription).to be_apns_sandbox
        expect(subscription.device_token).to eq(token)
        expect(subscription.device_token_digest).to eq(digest)
      end
    end
  end

  describe '.excluding_user' do
    it 'returns the subscriptions registered by other users' do
      user = create(:user)
      create(:mobile_device_push_subscription, user: user)
      other = create(:mobile_device_push_subscription)

      expect(described_class.excluding_user(user)).to contain_exactly(other)
    end
  end

  describe '.other_user_ids_for_device_token' do
    it 'returns the ids of the other users holding the token, not the caller nor other tokens' do
      user = create(:user)
      other_user = create(:user)
      device_token = 'ab' * 32
      # One row per APNs environment can exist for a token.
      create(:mobile_device_push_subscription, user: user, device_token: device_token)
      create(:mobile_device_push_subscription, :sandbox, user: other_user, device_token: device_token)
      create(:mobile_device_push_subscription, user: other_user)

      expect(described_class.other_user_ids_for_device_token(device_token, user))
        .to contain_exactly(other_user.id)
    end
  end

  describe 'device token normalization' do
    it 'lowercases tokens on assignment' do
      expect(described_class.normalize_value_for(:device_token, 'ABCDEF1234567890')).to eq('abcdef1234567890')
    end
  end

  describe '#effective_payload_mode and #content_key_bytes' do
    let(:key) { SecureRandom.random_bytes(32) }

    it 'is full without a key' do
      subscription = build(:mobile_device_push_subscription)

      expect(subscription.effective_payload_mode).to eq(:full)
      expect(subscription.content_key_bytes).to be_nil
    end

    it 'is encrypted with a key, and decodes it' do
      subscription = build(:mobile_device_push_subscription, content_key: Base64.strict_encode64(key))

      expect(subscription.effective_payload_mode).to eq(:encrypted)
      expect(subscription.content_key_bytes).to eq(key)
    end

    it 'stays id_only when the user asked for identifiers only, key or not' do
      subscription = build(:mobile_device_push_subscription, payload_mode: :id_only,
        content_key: Base64.strict_encode64(key))

      expect(subscription.effective_payload_mode).to eq(:id_only)
    end

    it 'encrypts the key at rest' do
      subscription = create(:mobile_device_push_subscription, content_key: Base64.strict_encode64(key))

      expect(subscription.reload.content_key).to eq(Base64.strict_encode64(key))
      expect(subscription.ciphertext_for(:content_key)).not_to include(Base64.strict_encode64(key))
    end

    it 'excludes the key from serializable_hash' do
      subscription = build(:mobile_device_push_subscription, content_key: Base64.strict_encode64(key))

      expect(subscription.serializable_hash).not_to have_key('content_key')
      expect(subscription.as_json).not_to have_key('content_key')
    end
  end

  describe '#content_key_current? and content_key_registered_at' do
    let(:key) { Base64.strict_encode64(SecureRandom.random_bytes(32)) }

    it 'is false without a key and stamps nothing' do
      subscription = create(:mobile_device_push_subscription)

      expect(subscription.content_key_registered_at).to be_nil
      expect(subscription).not_to be_content_key_current
    end

    it 'stamps a new key and reports it current' do
      subscription = create(:mobile_device_push_subscription, content_key: key)

      expect(subscription.content_key_registered_at).to be_within(1.minute).of(Time.current)
      expect(subscription).to be_content_key_current
    end

    it 'is false once the key is older than the maximum age, and the key still seals pushes' do
      subscription = create(:mobile_device_push_subscription, content_key: key)
      subscription.update_column(:content_key_registered_at, (described_class::CONTENT_KEY_MAX_AGE + 1.day).ago)

      expect(subscription).not_to be_content_key_current
      expect(subscription.effective_payload_mode).to eq(:encrypted)
    end

    it 'does not renew the stamp when the same key is saved again' do
      subscription = create(:mobile_device_push_subscription, content_key: key)
      stale_at = (described_class::CONTENT_KEY_MAX_AGE + 1.day).ago
      subscription.update_column(:content_key_registered_at, stale_at)

      subscription.update!(content_key: key, last_seen_at: Time.current)

      expect(subscription.reload.content_key_registered_at).to be_within(1.second).of(stale_at)
    end

    it 'renews the stamp when the key changes' do
      subscription = create(:mobile_device_push_subscription, content_key: key)
      subscription.update_column(:content_key_registered_at, (described_class::CONTENT_KEY_MAX_AGE + 1.day).ago)

      subscription.update!(content_key: Base64.strict_encode64(SecureRandom.random_bytes(32)))

      expect(subscription).to be_content_key_current
    end

    it 'stamps a stored key that lost its stamp' do
      subscription = create(:mobile_device_push_subscription, content_key: key)

      subscription.reset_owner_settings
      subscription.update!(content_key: key)

      expect(subscription.reload).to be_content_key_current
    end

    it 'clears the stamp with the key' do
      subscription = create(:mobile_device_push_subscription, content_key: key)

      subscription.reset_owner_settings
      subscription.save!

      expect(subscription.reload.content_key_registered_at).to be_nil
    end
  end

  describe '.clear_content_keys' do
    let_it_be(:user) { create(:user) }
    let_it_be(:other_user) { create(:user) }

    let(:key) { Base64.strict_encode64(SecureRandom.random_bytes(32)) }

    let!(:keyed) { create(:mobile_device_push_subscription, user: user, content_key: key) }
    let!(:other_keyed) { create(:mobile_device_push_subscription, user: other_user, content_key: key) }
    let!(:keyless) { create(:mobile_device_push_subscription, user: user) }

    it 'clears every stored key and its stamp' do
      expect(described_class.clear_content_keys).to eq(2)

      [keyed, other_keyed].each do |subscription|
        subscription.reload
        expect(subscription.content_key).to be_nil
        expect(subscription.content_key_registered_at).to be_nil
      end
    end

    it "clears only the given user's keys" do
      expect(described_class.clear_content_keys(user: user)).to eq(1)

      expect(keyed.reload.content_key).to be_nil
      expect(other_keyed.reload.content_key).to eq(key)
      expect(keyless.reload.content_key).to be_nil
    end
  end
end
