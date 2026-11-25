# frozen_string_literal: true

module Gitlab
  module Gpg
    class InvalidGpgSignatureUpdater
      def initialize(gpg_key)
        @gpg_key = gpg_key
      end

      # rubocop: disable CodeReuse/ActiveRecord
      def run
        [@gpg_key].concat(@gpg_key.subkeys).each do |key|
          Gitlab::Gpg.using_tmp_keychain do
            Gitlab::Gpg::CurrentKeyChain.add(key.key)
            signatures_to_update(key).find_each do |sig|
              sig.gpg_commit&.update_cached_signature!(sig, key)
            end
          end
        end
      end

      private

      # @note A verified signature linked to the key or subkey that made it
      #   keeps its status, so that commits signed with a subkey that has
      #   since expired stay verified. Only revoking that subkey checks them
      #   again.
      # @param key [GpgKey, GpgKeySubkey]
      # @return [ActiveRecord::Relation<CommitSignatures::GpgSignature>]
      def signatures_to_update(key)
        signatures = CommitSignatures::GpgSignature
          .select(:id, :commit_sha, :project_id)
          .where(gpg_key_primary_keyid: [key.keyid, key.fingerprint])
        verified = CommitSignatures::GpgSignature.verification_statuses[:verified]

        return signatures.where('gpg_key_id IS NULL OR verification_status <> ?', verified) if key.is_a?(::GpgKey)
        return signatures if Gitlab::Gpg::CurrentKeyChain.revoked_subkey?(key.fingerprint)

        signatures.where('gpg_key_subkey_id IS NULL OR verification_status <> ?', verified)
      end
      # rubocop: enable CodeReuse/ActiveRecord
    end
  end
end
