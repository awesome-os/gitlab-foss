# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Repositories::GpgKeys::UpdateService, feature_category: :source_code_management do
  let_it_be(:user) { create(:user) }

  let(:stored_key) { GpgHelpers::User1.public_key }
  let(:new_key) { GpgHelpers::User1.public_key_with_extra_signing_key }
  let(:current_user) { user }
  let(:extra_subkey_fingerprint) { 'B549163445E929C75BE33C7EE481AAC4D2E3AE11' }
  let!(:gpg_key) { create(:gpg_key, user: user, key: stored_key) }

  subject(:execute) { described_class.new(gpg_key, current_user: current_user, params: { key: new_key }).execute }

  shared_examples 'a refused update' do |reason|
    it 'answers an error and changes nothing', :aggregate_failures do
      expect(InvalidGpgSignatureUpdateWorker).not_to receive(:perform_async)
      expect(Notify).not_to receive(:updated_gpg_key_email)

      result = nil
      expect { result = execute }
        .to not_change { GpgKey.find(gpg_key.id).key }
        .and not_change { GpgKeySubkey.count }

      expect(result).to be_error
      expect(result.reason).to eq(reason)
      expect(result.message).to be_present
    end
  end

  describe '#execute' do
    it 'stores the merged key and the rows of its new subkeys', :aggregate_failures do
      result = execute

      expect(result).to be_success
      expect(result.payload).to include(
        gpg_key: gpg_key,
        updated: true,
        added_subkey_fingerprints: [extra_subkey_fingerprint]
      )
      expect(gpg_key.reload.subkeys.map(&:fingerprint)).to include(extra_subkey_fingerprint)
      expect(Gitlab::Gpg.subkeys_from_key(gpg_key.key)[GpgHelpers::User1.primary_keyid])
        .to include(a_hash_including(fingerprint: extra_subkey_fingerprint))
      expect(gpg_key.fingerprint).to eq(GpgHelpers::User1.fingerprint)
    end

    it 'creates the subkey rows from the merged key without listing its subkeys again', :aggregate_failures do
      expect(Gitlab::Gpg).not_to receive(:subkeys_from_key)

      expect(execute.payload[:added_subkey_fingerprints]).to eq([extra_subkey_fingerprint])
      expect(gpg_key.reload.subkeys.find_by(fingerprint: extra_subkey_fingerprint).keyid).to eq('E481AAC4D2E3AE11')
    end

    it 'checks the signatures of the key again' do
      expect(InvalidGpgSignatureUpdateWorker).to receive(:perform_async).with(gpg_key.id)

      execute
    end

    it 'emails the owner the subkeys the update added' do
      expect { execute }
        .to have_enqueued_mail(Notify, :updated_gpg_key_email).with(gpg_key.id, [extra_subkey_fingerprint], [])
    end

    context 'when the updated_gpg_key_email feature flag is disabled' do
      before do
        stub_feature_flags(updated_gpg_key_email: false)
      end

      it 'updates the key without emailing the owner', :aggregate_failures do
        result = nil
        expect { result = execute }.not_to have_enqueued_mail(Notify, :updated_gpg_key_email)

        expect(result.payload[:updated]).to be(true)
      end
    end

    context 'when the stored key has expired and the new version extends it' do
      let(:new_key) { GpgHelpers::User1.public_key_with_extended_expiration }

      before do
        # A key cannot be added once it has expired, so the stored text is set
        # as it reads when the key expires after it was added.
        gpg_key.update_column(:key, GpgHelpers::User1.expired_public_key)
        gpg_key.reload
      end

      it 'stores the extended key', :aggregate_failures do
        result = execute

        expect(result).to be_success
        expect(result.payload[:updated]).to be(true)
        expect(gpg_key.reload.primary_keyid).to eq(GpgHelpers::User1.primary_keyid)
        expect(gpg_key.user_infos.pluck(:email)).to include(GpgHelpers::User1.emails.first)
      end

      context 'and the same expired text is added again' do
        let(:new_key) { GpgHelpers::User1.expired_public_key }

        it_behaves_like 'a refused update', :expired_key
      end
    end

    context 'when the new version adds a user ID' do
      let(:new_key) { GpgHelpers::User1.public_key_with_extra_uid }

      it 'updates the key and emails the owner the user ID', :aggregate_failures do
        expect { expect(execute.payload[:updated]).to be(true) }
          .to have_enqueued_mail(Notify, :updated_gpg_key_email)
          .with(gpg_key.id, [], ['Nannie Bernhard <nannie.bernhard@example.org>'])

        expect(gpg_key.reload.user_infos.pluck(:email)).to include('nannie.bernhard@example.org')
      end
    end

    context 'when the new version only revokes a subkey' do
      let(:stored_key) { GpgHelpers::UserWithRevokedUid.public_key }
      let(:new_key) { GpgHelpers::UserWithRevokedUid.public_key_with_revoked_subkey }

      it 'updates the key without emailing the owner', :aggregate_failures do
        expect(InvalidGpgSignatureUpdateWorker).to receive(:perform_async).with(gpg_key.id)

        result = nil
        expect { result = execute }.not_to have_enqueued_mail(Notify, :updated_gpg_key_email)

        expect(result.payload).to include(updated: true, added_subkey_fingerprints: [])
        expect(gpg_key.reload.key).not_to eq(stored_key)
        expect(gpg_key.subkeys.map(&:fingerprint)).to eq(GpgHelpers::UserWithRevokedUid.subkey_fingerprints)
      end
    end

    context 'when the new version holds nothing new' do
      let(:stored_key) { GpgHelpers::User1.public_key_with_extra_signing_key }
      let(:new_key) { GpgHelpers::User1.public_key }

      it 'answers that the key is up to date and writes nothing', :aggregate_failures do
        expect(InvalidGpgSignatureUpdateWorker).not_to receive(:perform_async)

        result = nil
        expect { result = execute }.not_to change { GpgKey.find(gpg_key.id).updated_at }

        expect(result).to be_success
        expect(result.payload).to include(gpg_key: gpg_key, updated: false)
      end
    end

    context 'when the new version lacks a subkey the stored key has' do
      let(:stored_key) { GpgHelpers::User1.public_key_with_extra_signing_key }
      let(:new_key) { GpgHelpers::User1.public_key_with_extra_uid }

      it 'keeps the subkey in the stored key and adds the user ID', :aggregate_failures do
        expect(execute.payload).to include(updated: true, added_subkey_fingerprints: [])

        stored = GpgKey.find(gpg_key.id)
        expect(Gitlab::Gpg.subkeys_from_key(stored.key)[GpgHelpers::User1.primary_keyid])
          .to include(a_hash_including(fingerprint: extra_subkey_fingerprint))
        expect(stored.user_infos.pluck(:email)).to include('nannie.bernhard@example.org')
      end
    end

    context 'when the new version is older than the stored key' do
      let(:stored_key) { GpgHelpers::UserWithRevokedUid.public_key_with_revoked_subkey }
      let(:new_key) { GpgHelpers::UserWithRevokedUid.public_key }

      it 'keeps the subkey revocation and writes nothing', :aggregate_failures do
        expect(execute.payload).to include(updated: false)
        expect(GpgKey.find(gpg_key.id).key).to eq(stored_key)
      end
    end

    context 'when the key belongs to another user' do
      let(:current_user) { create(:user) }

      it_behaves_like 'a refused update', :forbidden
    end

    context 'when there is no current user' do
      let(:current_user) { nil }

      it_behaves_like 'a refused update', :forbidden
    end

    context 'when the text is not a public key block' do
      let(:new_key) { GpgHelpers::User1.secret_key }

      it_behaves_like 'a refused update', :invalid_key
    end

    context 'when the text is not a key' do
      let(:new_key) { "#{GpgKey::KEY_PREFIX}\nbogus\n#{GpgKey::KEY_SUFFIX}" }

      it_behaves_like 'a refused update', :different_key
    end

    context 'when the text carries the secret key' do
      let(:new_key) { GpgHelpers::User1.secret_key_labelled_public }

      it_behaves_like 'a refused update', :different_key
    end

    context 'when the text is another key' do
      let(:new_key) { GpgHelpers::User2.public_key }

      it_behaves_like 'a refused update', :different_key
    end

    context 'when the text holds the key and another one' do
      let(:new_key) do
        GpgHelpers.public_keys_in_one_block(GpgHelpers::User1.public_key_with_extra_signing_key,
          GpgHelpers::User2.public_key)
      end

      it_behaves_like 'a refused update', :different_key
    end

    context 'when the stored text holds more than one key' do
      let(:stored_key) { GpgHelpers.public_keys_in_one_block(GpgHelpers::User1.public_key, GpgHelpers::User2.public_key) }

      it_behaves_like 'a refused update', :several_stored_keys
    end

    context 'when the stored key has an oversized user ID and the upload is clean' do
      let(:key_with_oversized_uid) do
        size = Gitlab::Gpg::PacketGuard::MAX_USER_ID_SIZE + 1
        binary = Gitlab::Gpg::PacketGuard.dearmor_key(stored_key) +
          [0xCD, 255, size].pack('CCN') + ('x' * size)

        "#{GpgKey::KEY_PREFIX}\n\n#{Base64.strict_encode64(binary)}\n#{GpgKey::KEY_SUFFIX}"
      end

      before do
        # Simulate a key stored before packet validation was introduced.
        gpg_key.update_column(:key, key_with_oversized_uid)
      end

      it 'refuses the update before importing the stored key #security' do
        expect(Gitlab::Gpg::PacketGuard.key_rejection_reason(gpg_key.key)).to eq('oversized_user_id')
        expect(Gitlab::Gpg::PacketGuard.dearmor_key(new_key)).to be_present
        expect(GPGME::Key).not_to receive(:import)

        result = execute

        aggregate_failures do
          expect(result).to be_error
          expect(result.reason).to eq(:unreadable_stored_key)
          expect(gpg_key.reload.key).to eq(key_with_oversized_uid)
        end
      end
    end

    context 'when GnuPG cannot read the stored text' do
      before do
        gpg_key.update_column(:key, "#{GpgKey::KEY_PREFIX}\nbogus\n#{GpgKey::KEY_SUFFIX}")
      end

      it_behaves_like 'a refused update', :unreadable_stored_key
    end

    context 'when GnuPG lists the stored key but does not keep it' do
      before do
        allow(Gitlab::Gpg).to receive(:merge_key).and_return(
          Gitlab::Gpg::MergedKey.new(key: nil, stored_fingerprints: [GpgHelpers::User1.fingerprint],
            new_fingerprints: [GpgHelpers::User1.fingerprint], secret_key_read: false, changed: changed,
            trust: nil, subkeys: [])
        )
      end

      context 'and the new version holds nothing new' do
        let(:changed) { false }

        it_behaves_like 'a refused update', :unreadable_stored_key
      end

      context 'and the new version adds something' do
        let(:changed) { true }

        it_behaves_like 'a refused update', :unreadable_stored_key
      end
    end

    context 'when the merged key cannot be used to verify signatures' do
      before do
        allow(Gitlab::Gpg).to receive(:merge_key).and_wrap_original do |original, *args|
          original.call(*args).tap { |merged| merged.trust = :disabled }
        end
      end

      it_behaves_like 'a refused update', :unusable_key
    end

    context 'when the new version revokes the key' do
      let(:new_key) { GpgHelpers::User1.revoked_public_key }

      it_behaves_like 'a refused update', :revoked_key
    end

    context 'when the key is expired after the merge' do
      let(:new_key) { GpgHelpers::User1.expired_public_key }

      it_behaves_like 'a refused update', :expired_key
    end

    context 'when the merged key lacks a subkey the key has a row for' do
      before do
        create(:gpg_key_subkey, gpg_key: gpg_key, keyid: 'E481AAC4D2E3AE10',
          fingerprint: 'B549163445E929C75BE33C7EE481AAC4D2E3AE10')
      end

      it_behaves_like 'a refused update', :subkeys_missing
    end

    context 'when the merged key is larger than a key can be' do
      before do
        stub_const("#{described_class}::MAX_KEY_BYTESIZE", 100)
      end

      it_behaves_like 'a refused update', :key_too_large

      context 'and the new version holds nothing new' do
        let(:new_key) { stored_key }

        it 'answers that the key is up to date' do
          expect(execute.payload).to include(updated: false)
        end
      end
    end

    context 'when another key holds a subkey the new version adds' do
      before do
        create(:gpg_key_subkey, gpg_key: create(:another_gpg_key),
          keyid: extra_subkey_fingerprint[-16..], fingerprint: extra_subkey_fingerprint)
      end

      it_behaves_like 'a refused update', :subkey_taken
    end

    context 'when the stored text changed after the service read it' do
      let(:other_version) { GpgHelpers::User1.public_key_with_extra_uid }

      before do
        GpgKey.find(gpg_key.id).update!(key: other_version)
      end

      it 'answers an error and keeps the other version', :aggregate_failures do
        result = execute

        expect(result).to be_error
        expect(result.reason).to eq(:key_changed)
        expect(GpgKey.find(gpg_key.id).key).to eq(other_version)
      end
    end

    context 'when the key was removed after the service read it' do
      before do
        GpgKey.find(gpg_key.id).destroy!
      end

      it 'answers an error' do
        expect(execute.reason).to eq(:not_found)
      end
    end
  end
end
