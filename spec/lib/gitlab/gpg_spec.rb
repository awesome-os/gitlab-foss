# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Gpg, feature_category: :source_code_management do
  describe '.fingerprints_from_key' do
    before do
      # make sure that each method is using the temporary keychain
      expect(described_class).to receive(:using_tmp_keychain).and_call_original
    end

    it 'returns CurrentKeyChain.fingerprints_from_key' do
      expect(Gitlab::Gpg::CurrentKeyChain).to receive(:fingerprints_from_key).with(GpgHelpers::User1.public_key)

      described_class.fingerprints_from_key(GpgHelpers::User1.public_key)
    end
  end

  describe '.primary_keyids_from_key' do
    it 'returns the keyid' do
      expect(
        described_class.primary_keyids_from_key(GpgHelpers::User1.public_key)
      ).to eq [GpgHelpers::User1.primary_keyid]
    end

    it 'returns an empty array when the key is invalid' do
      expect(
        described_class.primary_keyids_from_key('bogus')
      ).to eq []
    end
  end

  describe '.subkeys_from_key' do
    it 'returns the subkeys by primary key' do
      all_subkeys = described_class.subkeys_from_key(GpgHelpers::User1.public_key)
      subkeys = all_subkeys[GpgHelpers::User1.primary_keyid]

      expect(subkeys).to be_present
      expect(subkeys.first[:keyid]).to be_present
      expect(subkeys.first[:fingerprint]).to be_present
    end

    it 'returns an empty array when there are not subkeys' do
      all_subkeys = described_class.subkeys_from_key(GpgHelpers::User4.public_key)

      expect(all_subkeys[GpgHelpers::User4.primary_keyid]).to be_empty
    end
  end

  describe '.user_infos_from_key' do
    it 'returns the names and emails' do
      user_infos = described_class.user_infos_from_key(GpgHelpers::User1.public_key)
      expect(user_infos).to eq([{
        name: GpgHelpers::User1.names.first,
        email: GpgHelpers::User1.emails.first
      }])
    end

    it 'returns an empty array when the key is invalid' do
      expect(
        described_class.user_infos_from_key('bogus')
      ).to eq []
    end

    it 'downcases the email' do
      public_key = double(:key)
      fingerprints = double(:fingerprints)
      uid = double(:uid, name: +'Nannie Bernhard', email: +'NANNIE.BERNHARD@EXAMPLE.COM', revoked?: false)
      raw_key = double(:raw_key, uids: [uid])
      allow(Gitlab::Gpg::CurrentKeyChain).to receive(:fingerprints_from_key).with(public_key).and_return(fingerprints)
      allow(GPGME::Key).to receive(:find).with(:public, anything).and_return([raw_key])

      user_infos = described_class.user_infos_from_key(public_key)
      expect(user_infos).to eq([{
        name: 'Nannie Bernhard',
        email: 'nannie.bernhard@example.com'
      }])
    end

    it 'rejects non UTF-8 names and addresses' do
      public_key = double(:key)
      fingerprints = double(:fingerprints)
      email = (+"\xEEch@test.com").force_encoding('ASCII-8BIT')
      uid = double(:uid, name: +'Test User', email: email, revoked?: false)
      raw_key = double(:raw_key, uids: [uid])
      allow(Gitlab::Gpg::CurrentKeyChain).to receive(:fingerprints_from_key).with(public_key).and_return(fingerprints)
      allow(GPGME::Key).to receive(:find).with(:public, anything).and_return([raw_key])

      user_infos = described_class.user_infos_from_key(public_key)
      expect(user_infos).to eq([])
    end

    it 'rejects revoked uids and keeps the live ones' do
      user_infos = described_class.user_infos_from_key(GpgHelpers::UserWithRevokedUid.public_key)

      expect(user_infos).to eq([{
        name: GpgHelpers::UserWithRevokedUid.names.first,
        email: GpgHelpers::UserWithRevokedUid.emails.first
      }])
      expect(user_infos.map { |info| info[:email] })
        .not_to include(GpgHelpers::UserWithRevokedUid.revoked_emails.first)
    end

    it 'returns an empty array when every uid of the key is revoked' do
      user_infos = described_class.user_infos_from_key(GpgHelpers::UserWithOnlyRevokedUid.public_key)

      expect(user_infos).to eq([])
    end
  end

  describe '.merge_key' do
    let(:stored_key) { GpgHelpers::User1.public_key }
    let(:new_key) { GpgHelpers::User1.public_key_with_extra_signing_key }
    let(:extra_subkey_fingerprint) { 'B549163445E929C75BE33C7EE481AAC4D2E3AE11' }

    subject(:merged) { described_class.merge_key(stored_key, new_key) }

    it 'works in a temporary keychain' do
      expect(described_class).to receive(:using_tmp_keychain).and_call_original

      merged
    end

    it 'merges the new version into the stored key', :aggregate_failures do
      expect(merged).to have_attributes(
        stored_fingerprints: [GpgHelpers::User1.fingerprint],
        new_fingerprints: [GpgHelpers::User1.fingerprint],
        secret_key_read: false,
        changed: true,
        trust: nil,
        added_user_ids: []
      )
      expect(merged.subkey_fingerprints).to include(extra_subkey_fingerprint)
      expect(merged.key).to start_with(GpgKey::KEY_PREFIX)
      expect(described_class.subkeys_from_key(merged.key)[GpgHelpers::User1.primary_keyid])
        .to include(a_hash_including(fingerprint: extra_subkey_fingerprint))
    end

    it 'lists the subkeys of the merged key as .subkeys_from_key does' do
      expect(merged.subkeys).to eq(described_class.subkeys_from_key(merged.key)[GpgHelpers::User1.primary_keyid])
    end

    it 'lists the user IDs the new version adds' do
      merged = described_class.merge_key(stored_key, GpgHelpers::User1.public_key_with_extra_uid)

      expect(merged).to have_attributes(changed: true,
        added_user_ids: ['Nannie Bernhard <nannie.bernhard@example.org>'])
    end

    context 'when the new version holds nothing the stored key lacks' do
      let(:stored_key) { GpgHelpers::User1.public_key_with_extra_signing_key }
      let(:new_key) { GpgHelpers::User1.public_key }

      it 'keeps every subkey of the stored key and reports no change', :aggregate_failures do
        expect(merged).to have_attributes(changed: false, added_user_ids: [])
        expect(merged.subkey_fingerprints).to include(extra_subkey_fingerprint)
      end
    end

    context 'when the new version revokes a subkey' do
      let(:stored_key) { GpgHelpers::UserWithRevokedUid.public_key }
      let(:new_key) { GpgHelpers::UserWithRevokedUid.public_key_with_revoked_subkey }

      it 'keeps the revoked subkey and reports a change', :aggregate_failures do
        expect(merged).to have_attributes(changed: true, trust: nil, added_user_ids: [])
        expect(merged.subkey_fingerprints).to eq(GpgHelpers::UserWithRevokedUid.subkey_fingerprints)
      end
    end

    context 'when the new version is older than the stored key' do
      let(:stored_key) { GpgHelpers::UserWithRevokedUid.public_key_with_revoked_subkey }
      let(:new_key) { GpgHelpers::UserWithRevokedUid.public_key }

      it 'reports no change and keeps the subkey revocation', :aggregate_failures do
        expect(merged.changed).to be(false)

        subkey_fingerprint = GpgHelpers::UserWithRevokedUid.subkey_fingerprints.first
        described_class.using_tmp_keychain do
          described_class::CurrentKeyChain.add(merged.key)
          subkeys = GPGME::Ctx.new { |ctx| ctx.keys(subkey_fingerprint).first }.subkeys

          expect(subkeys.find { |subkey| subkey.fpr == subkey_fingerprint }.trust).to eq(:revoked)
        end
      end
    end

    context 'when the new text is another key' do
      let(:new_key) { GpgHelpers::User2.public_key }

      it 'reports its fingerprint and exports only the stored key', :aggregate_failures do
        expect(merged.new_fingerprints).to eq([GpgHelpers::User2.fingerprint])
        expect(described_class.fingerprints_from_key(merged.key)).to eq([GpgHelpers::User1.fingerprint])
      end
    end

    context 'when the new text holds several keys' do
      let(:new_key) do
        GpgHelpers.public_keys_in_one_block(GpgHelpers::User1.public_key_with_extra_signing_key,
          GpgHelpers::User2.public_key)
      end

      it 'reports every fingerprint' do
        expect(merged.new_fingerprints).to contain_exactly(GpgHelpers::User1.fingerprint, GpgHelpers::User2.fingerprint)
      end
    end

    context 'when the stored text holds several keys' do
      let(:stored_key) { GpgHelpers.public_keys_in_one_block(GpgHelpers::User1.public_key, GpgHelpers::User2.public_key) }

      it 'reports every stored fingerprint' do
        expect(merged.stored_fingerprints)
          .to contain_exactly(GpgHelpers::User1.fingerprint, GpgHelpers::User2.fingerprint)
      end
    end

    context 'when the stored text holds no key' do
      let(:stored_key) do
        user_id_packet = "\xB4\x06nobody".b

        "-----BEGIN PGP PUBLIC KEY BLOCK-----\n\n#{Base64.strict_encode64(user_id_packet)}\n" \
          "-----END PGP PUBLIC KEY BLOCK-----\n"
      end

      it 'reports no stored key, subkey or added user ID', :aggregate_failures do
        expect(merged).to have_attributes(key: nil, stored_fingerprints: [], subkeys: [], added_user_ids: [])
        expect(merged.new_fingerprints).to eq([GpgHelpers::User1.fingerprint])
      end
    end

    context 'when the stored text is not a key' do
      let(:stored_key) { 'bogus' }

      it 'reports no fingerprint and no change, and exports no key' do
        expect(merged).to have_attributes(key: nil, stored_fingerprints: [], new_fingerprints: [], changed: false,
          trust: nil, subkey_fingerprints: [])
      end
    end

    context 'when the new text is not a key' do
      let(:new_key) { 'bogus' }

      it 'reports no fingerprint and no change', :aggregate_failures do
        expect(merged.new_fingerprints).to be_empty
        expect(merged.changed).to be(false)
      end
    end

    context 'when the new text carries the secret key' do
      let(:new_key) { GpgHelpers::User1.secret_key_labelled_public }

      it 'rejects the secret key before importing it', :aggregate_failures do
        expect(GPGME::Key).to receive(:import)
          .with(Gitlab::Gpg::PacketGuard.dearmor_key(stored_key)).once.and_call_original

        expect(merged.secret_key_read).to be(false)
        expect(merged.new_fingerprints).to be_empty
        expect(merged.changed).to be(false)
      end
    end

    context 'when the new version revokes the key' do
      let(:new_key) { GpgHelpers::User1.revoked_public_key }

      it 'reports the merged key as revoked' do
        expect(merged.trust).to eq(:revoked)
      end
    end

    context 'when the new version lets the key expire' do
      let(:new_key) { GpgHelpers::User1.expired_public_key }

      it 'reports the merged key as expired' do
        expect(merged.trust).to eq(:expired)
      end
    end
  end

  describe '.current_home_dir' do
    let(:default_home_dir) { GPGME::Engine.dirinfo('homedir') }

    it 'returns the default value when no explicit home dir has been set' do
      expect(described_class.current_home_dir).to eq default_home_dir
    end

    it 'returns the explicitly set home dir' do
      GPGME::Engine.home_dir = '/tmp/gpg'

      expect(described_class.current_home_dir).to eq '/tmp/gpg'

      GPGME::Engine.home_dir = GPGME::Engine.dirinfo('homedir')
    end

    it 'returns the default value when explicitly setting the home dir to nil' do
      GPGME::Engine.home_dir = nil

      expect(described_class.current_home_dir).to eq default_home_dir
    end
  end

  describe '.using_tmp_keychain' do
    it "the second thread does not change the first thread's directory" do
      thread1 = Thread.new do
        described_class.using_tmp_keychain do
          dir = described_class.current_home_dir
          sleep 0.1
          expect(described_class.current_home_dir).to eq dir
        end
      end

      thread2 = Thread.new do
        described_class.using_tmp_keychain do
          sleep 0.2
        end
      end

      thread1.join
      thread2.join
    end

    it 'allows recursive execution in the same thread' do
      expect do
        described_class.using_tmp_keychain do
          described_class.using_tmp_keychain do
            nil
          end
        end
      end.not_to raise_error
    end

    it 'keeps track of created and removed keychains in counters' do
      created = Gitlab::Metrics.counter(:gpg_tmp_keychains_created_total, 'The number of temporary GPG keychains')
      removed = Gitlab::Metrics.counter(:gpg_tmp_keychains_removed_total, 'The number of temporary GPG keychains')

      initial_created = created.get
      initial_removed = removed.get

      described_class.using_tmp_keychain do
        expect(created.get).to eq(initial_created + 1)
        expect(removed.get).to eq(initial_removed)
      end

      expect(removed.get).to eq(initial_removed + 1)
    end

    it 'cleans up the tmp directory after finishing' do
      tmp_directory = nil

      described_class.using_tmp_keychain do
        tmp_directory = described_class.current_home_dir
        expect(File.exist?(tmp_directory)).to be true
      end

      expect(tmp_directory).not_to be_nil
      expect(File.exist?(tmp_directory)).to be false
    end

    it 'does not fail if the homedir was deleted while running' do
      expect do
        described_class.using_tmp_keychain do
          FileUtils.rm_rf(described_class.current_home_dir)
        end
      end.not_to raise_error
    end

    it 'tracks an exception when cleaning up the tmp dir fails' do
      expected_exception = described_class::CleanupError.new('cleanup failed')
      expected_tmp_dir = nil

      expect(described_class).to receive(:cleanup_tmp_dir).and_raise(expected_exception)
      allow(Gitlab::ErrorTracking).to receive(:track_and_raise_for_dev_exception)

      described_class.using_tmp_keychain do
        expected_tmp_dir = described_class.current_home_dir
        FileUtils.touch(File.join(expected_tmp_dir, 'dummy.file'))
      end

      expect(Gitlab::ErrorTracking).to have_received(:track_and_raise_for_dev_exception).with(
        expected_exception,
        issue_url: 'https://gitlab.com/gitlab-org/gitlab/issues/20918',
        tmp_dir: expected_tmp_dir, contents: ['dummy.file']
      )
    end

    shared_examples 'multiple deletion attempts of the tmp-dir' do |seconds|
      let(:tmp_dir) do
        tmp_dir = Dir.mktmpdir
        allow(Dir).to receive(:mktmpdir).and_return(tmp_dir)
        tmp_dir
      end

      before do
        # Stub all the other calls for `rm_rf`
        allow(FileUtils).to receive(:rm_rf).with(any_args).and_call_original
      end

      it "tries for #{seconds} or 15 times" do
        expect(Retriable).to receive(:retriable).with(a_hash_including(max_elapsed_time: seconds, tries: 15))

        described_class.using_tmp_keychain { nil }
      end

      it 'tries at least 2 times to remove the tmp dir before raising', :aggregate_failures do
        expect(Retriable).to receive(:sleep).at_least(:twice)
        expect(FileUtils).to receive(:rm_rf).with(tmp_dir).at_least(:twice).and_raise('Deletion failed')

        expect { described_class.using_tmp_keychain { nil } }.to raise_error(described_class::CleanupError)
      end

      it 'does not attempt multiple times when the deletion succeeds' do
        expect(Retriable).to receive(:sleep).once
        expect(FileUtils).to receive(:rm_rf).with(tmp_dir).once.and_raise('Deletion failed')
        expect(FileUtils).to receive(:rm_rf).with(tmp_dir).and_call_original

        expect { described_class.using_tmp_keychain { nil } }.not_to raise_error

        expect(File.exist?(tmp_dir)).to be false
      end
    end

    it_behaves_like 'multiple deletion attempts of the tmp-dir', described_class::FG_CLEANUP_RUNTIME_S

    context 'when running in Sidekiq' do
      before do
        allow(Gitlab::Runtime).to receive(:sidekiq?).and_return(true)
      end

      it_behaves_like 'multiple deletion attempts of the tmp-dir', described_class::BG_CLEANUP_RUNTIME_S
    end
  end
end

RSpec.describe Gitlab::Gpg::CurrentKeyChain, feature_category: :source_code_management do
  let(:key_with_oversized_uid) do
    size = Gitlab::Gpg::PacketGuard::MAX_USER_ID_SIZE + 1
    binary = [0xC6, 1, 4].pack('C*') + [0xCD, 255, size].pack('CCN') + ('x' * size)

    "-----BEGIN PGP PUBLIC KEY BLOCK-----\n\n#{Base64.strict_encode64(binary)}\n-----END PGP PUBLIC KEY BLOCK-----"
  end

  around do |example|
    Gitlab::Gpg.using_tmp_keychain do
      example.run
    end
  end

  describe '.add' do
    it 'does not import a key with an oversized user ID #security', :aggregate_failures do
      expect(GPGME::Key).not_to receive(:import)

      expect(described_class.add(key_with_oversized_uid)).to be_nil
    end

    it 'stores the key in the keychain' do
      expect(GPGME::Key.find(:public, GpgHelpers::User1.fingerprint)).to eq []

      described_class.add(GpgHelpers::User1.public_key)

      keys = GPGME::Key.find(:public, GpgHelpers::User1.fingerprint)
      expect(keys.count).to eq 1
      expect(keys.first).to have_attributes(
        email: GpgHelpers::User1.emails.first,
        fingerprint: GpgHelpers::User1.fingerprint
      )
    end
  end

  describe '.fingerprints_from_key' do
    it 'returns no fingerprints for an oversized user ID without importing #security', :aggregate_failures do
      expect(GPGME::Key).not_to receive(:import)

      expect(described_class.fingerprints_from_key(key_with_oversized_uid)).to eq([])
    end

    it 'returns the fingerprint' do
      expect(
        described_class.fingerprints_from_key(GpgHelpers::User1.public_key)
      ).to eq [GpgHelpers::User1.fingerprint]
    end

    it 'returns an empty array when the key is invalid' do
      expect(
        described_class.fingerprints_from_key('bogus')
      ).to eq []
    end
  end

  describe '.revoked_subkey?' do
    let(:subkey_fingerprint) { GpgHelpers::UserWithRevokedUid.subkey_fingerprints.first }

    it 'returns true for a subkey the key in the keychain revokes' do
      described_class.add(GpgHelpers::UserWithRevokedUid.public_key_with_revoked_subkey)

      expect(described_class.revoked_subkey?(subkey_fingerprint)).to be(true)
    end

    it 'returns false for a subkey that is not revoked' do
      described_class.add(GpgHelpers::UserWithRevokedUid.public_key)

      expect(described_class.revoked_subkey?(subkey_fingerprint)).to be(false)
    end

    it 'returns false for a subkey that is not in the keychain' do
      expect(described_class.revoked_subkey?(subkey_fingerprint)).to be(false)
    end

    it 'returns false for the primary key of a key whose subkey is revoked' do
      described_class.add(GpgHelpers::UserWithRevokedUid.public_key_with_revoked_subkey)

      expect(described_class.revoked_subkey?(GpgHelpers::UserWithRevokedUid.fingerprint)).to be(false)
    end

    it 'returns false for a subkey that has expired' do
      described_class.add(GpgHelpers::UserWithRevokedUid.public_key_with_expired_subkey)

      expect(described_class.revoked_subkey?(subkey_fingerprint)).to be(false)
    end

    context 'when the key revokes another of its subkeys' do
      before do
        described_class.add(GpgHelpers::UserWithRevokedUid.public_key_with_revoked_second_subkey)
      end

      it 'returns true for the revoked subkey' do
        revoked_fingerprint = GpgHelpers::UserWithRevokedUid.revoked_second_subkey_fingerprint

        expect(described_class.revoked_subkey?(revoked_fingerprint)).to be(true)
      end

      it 'returns false for the subkey that is still valid' do
        expect(described_class.revoked_subkey?(subkey_fingerprint)).to be(false)
      end
    end
  end
end
