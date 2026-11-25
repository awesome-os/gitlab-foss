# frozen_string_literal: true

module Repositories
  module GpgKeys
    # Merges a new version of a stored GPG key into it, as `gpg --import` does,
    # so nothing is removed and an older version cannot undo a revocation or an
    # expiration change.
    class UpdateService
      # Rack refuses a form body over 4 MiB, so the add form cannot store a
      # larger key, and an update does not grow one past that either.
      MAX_KEY_BYTESIZE = 4.megabytes

      SubkeysMissingError = Class.new(StandardError)

      def initialize(gpg_key, current_user:, params:)
        @gpg_key = gpg_key
        @current_user = current_user
        @stored_key = gpg_key.key
        @new_key = params[:key].to_s.strip
      end

      def execute
        refusal = refusal_before_merge || refusal_after_merge
        return refusal if refusal
        return success(updated: false) unless merged_key.changed

        added_subkeys = store_merged_key
        unless added_subkeys
          return error(s_('Profiles|The GPG key changed while it was being updated. Try again.'), :key_changed)
        end

        notify_owner(added_subkeys)
        gpg_key.update_invalid_gpg_signatures

        success(updated: true, added_subkey_fingerprints: added_subkeys.map(&:fingerprint))
      rescue SubkeysMissingError
        error(s_('Profiles|GitLab could not keep every subkey of this GPG key. Remove the key and add it again.'),
          :subkeys_missing)
      rescue ActiveRecord::RecordNotFound
        error(s_('Profiles|The GPG key no longer exists.'), :not_found)
      rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique
        error(s_('Profiles|A subkey of this GPG key belongs to another key.'), :subkey_taken)
      end

      private

      attr_reader :gpg_key, :current_user, :stored_key, :new_key

      def merged_key
        @merged_key ||= ::Gitlab::Gpg.merge_key(stored_key, new_key)
      end

      def refusal_before_merge
        unless gpg_key.user_id && gpg_key.user_id == current_user&.id
          return error(s_('Profiles|You can only update your own GPG keys.'), :forbidden)
        end

        return if ::GpgKey::KEY_FORMAT.match?(new_key)

        message = format(s_("Profiles|A public GPG key begins with '%{prefix}' and ends with '%{suffix}'."),
          prefix: ::GpgKey::KEY_PREFIX, suffix: ::GpgKey::KEY_SUFFIX)
        error(message, :invalid_key)
      end

      def refusal_after_merge
        if merged_key.secret_key_read
          message = format(s_('Profiles|This is a private GPG key. Add its public key, which %{command} prints.'),
            command: 'gpg --armor --export')
          error(message, :secret_key)
        elsif merged_key.key.nil?
          error(s_('Profiles|GitLab cannot read the stored GPG key. Remove it and add it again.'),
            :unreadable_stored_key)
        elsif merged_key.stored_fingerprints.size > 1
          error(s_('Profiles|This GPG key holds more than one key and cannot be updated. ' \
            'Remove it, then add the new version.'), :several_stored_keys)
        elsif merged_key.new_fingerprints != merged_key.stored_fingerprints
          error(s_('Profiles|The new version must hold exactly one key, the key it updates.'), :different_key)
        else
          refusal_of_merged_key
        end
      end

      def refusal_of_merged_key
        case merged_key.trust
        when :revoked
          error(s_('Profiles|This GPG key is revoked. To stop GitLab from using it, ' \
            'select Revoke or Remove next to the key.'), :revoked_key)
        when :expired
          error(s_('Profiles|This GPG key is expired. Extend its expiration date, then add it again.'), :expired_key)
        when nil
          if merged_key.changed && merged_key.key.bytesize > MAX_KEY_BYTESIZE
            error(s_('Profiles|The updated GPG key is too large.'), :key_too_large)
          end
        else
          error(s_('Profiles|This GPG key cannot be used to verify signatures.'), :unusable_key)
        end
      end

      # The row lock makes a concurrent update of the same key wait, and the
      # comparison makes it stop rather than overwrite what the first one stored.
      # Returns the added subkeys, or nil when the stored key changed meanwhile.
      def store_merged_key
        ::GpgKey.transaction do
          gpg_key.lock!
          next unless gpg_key.key == stored_key

          # Signatures link to subkey rows, so the stored text must keep every subkey that has one.
          raise SubkeysMissingError if (gpg_key.subkeys.map(&:fingerprint) - merged_key.subkey_fingerprints).any?

          gpg_key.key = merged_key.key
          gpg_key.save!
          gpg_key.generate_subkeys(merged_key.subkeys)
        end
      end

      def notify_owner(added_subkeys)
        added_user_ids = merged_key.added_user_ids
        return if added_subkeys.empty? && added_user_ids.empty?
        return unless Feature.enabled?(:updated_gpg_key_email, gpg_key.user)

        NotificationService.new.updated_gpg_key(gpg_key, added_subkeys.map(&:fingerprint), added_user_ids)
      end

      def success(**payload)
        ServiceResponse.success(payload: { gpg_key: gpg_key, **payload })
      end

      def error(message, reason)
        ServiceResponse.error(message: message, reason: reason)
      end
    end
  end
end

Repositories::GpgKeys::UpdateService.prepend_mod
