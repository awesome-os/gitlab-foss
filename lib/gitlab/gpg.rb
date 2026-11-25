# frozen_string_literal: true

module Gitlab
  module Gpg
    extend self

    CleanupError = Class.new(StandardError)
    BG_CLEANUP_RUNTIME_S = 10
    FG_CLEANUP_RUNTIME_S = 1

    MUTEX = Mutex.new

    # What .merge_key returns. trust is nil when the merged key is usable, else
    # :revoked, :expired, :disabled or :invalid. subkeys lists the subkeys of the
    # merged key as .subkeys_from_key does. added_user_ids lists the user IDs the
    # new version added, as GnuPG prints them.
    MergedKey = Struct.new(
      :key, :stored_fingerprints, :new_fingerprints, :secret_key_read, :changed, :trust, :subkeys,
      :added_user_ids,
      keyword_init: true
    ) do
      def subkey_fingerprints
        subkeys.map { |subkey| subkey.fetch(:fingerprint) }
      end
    end

    module CurrentKeyChain
      extend self

      def add(key)
        binary = PacketGuard.dearmor_key(key)
        return unless binary

        GPGME::Key.import(binary)
      end

      def fingerprints_from_key(key)
        binary = PacketGuard.dearmor_key(key)
        return [] unless binary

        import = GPGME::Key.import(binary)

        return [] if import.imported == 0

        import.imports.map(&:fingerprint)
      end

      # @note GPGME::Key.find would hide a key that is revoked or expired, so
      #   the keys are listed with GPGME::Ctx#keys, which returns every one of
      #   them.
      # @param fingerprint [String] the subkey's fingerprint
      # @return [Boolean] whether a key in the keychain revokes that subkey
      def revoked_subkey?(fingerprint)
        GPGME::Ctx.new { |ctx| ctx.keys(fingerprint) }
          .flat_map { |raw_key| raw_key.subkeys.drop(1) }
          .any? { |subkey| subkey.fingerprint == fingerprint && subkey.trust == :revoked }
      end
    end

    def fingerprints_from_key(key)
      using_tmp_keychain do
        CurrentKeyChain.fingerprints_from_key(key)
      end
    end

    def primary_keyids_from_key(key)
      using_tmp_keychain do
        fingerprints = CurrentKeyChain.fingerprints_from_key(key)

        GPGME::Key.find(:public, fingerprints).map { |raw_key| raw_key.primary_subkey.keyid }
      end
    end

    def subkeys_from_key(key)
      using_tmp_keychain do
        fingerprints = CurrentKeyChain.fingerprints_from_key(key)
        raw_keys     = GPGME::Key.find(:public, fingerprints)

        raw_keys.each_with_object({}) do |raw_key, grouped_subkeys|
          primary_subkey_id = raw_key.primary_subkey.keyid

          grouped_subkeys[primary_subkey_id] = raw_key.subkeys[1..].map do |s|
            { keyid: s.keyid, fingerprint: s.fingerprint }
          end
        end
      end
    end

    def user_infos_from_key(key)
      using_tmp_keychain do
        fingerprints = CurrentKeyChain.fingerprints_from_key(key)

        GPGME::Key.find(:public, fingerprints).flat_map do |raw_key|
          raw_key.uids.each_with_object([]) do |uid, arr|
            # A revoked UID is still carried inside the key, because a revocation
            # adds a signature rather than removing the UID. The key holder has
            # withdrawn that identity, so it must not be offered for verification
            # against their email addresses. GPGME's invalid flag is not checked
            # here: GnuPG drops a UID without a valid self-signature at import,
            # so such a UID never reaches this listing.
            next if uid.revoked?

            name = uid.name.force_encoding('UTF-8')
            email = uid.email.force_encoding('UTF-8')
            arr << { name: name, email: email.downcase } if name.valid_encoding? && email.valid_encoding?
          end
        end
      end
    end

    # Merges a new version of a key into the stored one, as `gpg --import` does.
    # Lists the result with GPGME::Ctx#keys, since GPGME::Key.find hides an unusable key.
    def merge_key(stored_key, new_key)
      stored_binary = PacketGuard.dearmor_key(stored_key)
      unless stored_binary
        return MergedKey.new(stored_fingerprints: [], new_fingerprints: [], secret_key_read: false,
          changed: false, subkeys: [], added_user_ids: [])
      end

      new_binary = PacketGuard.dearmor_key(new_key)

      using_tmp_keychain do
        stored_fingerprints = GPGME::Key.import(stored_binary).imports.map(&:fpr).uniq
        fingerprint = stored_fingerprints.first
        stored_user_ids = user_ids_of(fingerprint)
        result = GPGME::Key.import(new_binary) if new_binary
        raw_key = GPGME::Ctx.new { |ctx| ctx.keys(fingerprint).first } if fingerprint
        changes = if result
                    [result.new_user_ids, result.new_sub_keys, result.new_signatures, result.new_revocations]
                  else
                    []
                  end

        MergedKey.new(
          key: (GPGME::Key.export(fingerprint, armor: true).to_s if raw_key),
          stored_fingerprints: stored_fingerprints,
          new_fingerprints: result ? result.imports.map(&:fpr).uniq : [],
          secret_key_read: result&.secret_read.to_i > 0,
          changed: changes.sum > 0,
          trust: raw_key&.trust,
          subkeys: raw_key ? raw_key.subkeys.drop(1).map { |s| { keyid: s.keyid, fingerprint: s.fpr } } : [],
          added_user_ids: user_ids_of(fingerprint) - stored_user_ids
        )
      end
    end

    # Allows thread safe switching of temporary keychain files
    #
    # 1. The current thread may use nesting of temporary keychain
    # 2. Another thread needs to wait for the lock to be released
    def using_tmp_keychain(&block)
      if MUTEX.locked? && MUTEX.owned?
        optimistic_using_tmp_keychain(&block)
      else
        ActiveSupport::Dependencies.interlock.permit_concurrent_loads do
          MUTEX.synchronize do
            optimistic_using_tmp_keychain(&block)
          end
        end
      end
    end

    # 1. Returns the custom home directory if one has been set by calling
    #    `GPGME::Engine.home_dir=`
    # 2. Returns the default home directory otherwise
    def current_home_dir
      GPGME::Engine.info.first.home_dir || GPGME::Engine.dirinfo('homedir')
    end

    private

    # The user IDs of the key with this fingerprint in the current keychain.
    def user_ids_of(fingerprint)
      raw_key = GPGME::Ctx.new { |ctx| ctx.keys(fingerprint).first } if fingerprint
      return [] unless raw_key

      raw_key.uids.map { |uid| uid.uid.dup.force_encoding(Encoding::UTF_8).scrub }
    end

    def optimistic_using_tmp_keychain
      previous_dir = current_home_dir
      tmp_dir = Dir.mktmpdir
      GPGME::Engine.home_dir = tmp_dir
      tmp_keychains_created.increment

      yield
    ensure
      GPGME::Engine.home_dir = previous_dir

      begin
        cleanup_tmp_dir(tmp_dir)
      rescue CleanupError => e
        folder_contents = Dir.children(tmp_dir)
        # This means we left a GPG-agent process hanging. Logging the problem in
        # sentry will make this more visible.
        Gitlab::ErrorTracking.track_and_raise_for_dev_exception(e,
          issue_url: 'https://gitlab.com/gitlab-org/gitlab/issues/20918',
          tmp_dir: tmp_dir, contents: folder_contents)
      end

      tmp_keychains_removed.increment unless File.exist?(tmp_dir)
    end

    def cleanup_tmp_dir(tmp_dir)
      # Retry when removing the tmp directory failed, as we may run into a
      # race condition:
      # The `gpg-agent` agent process may clean up some files as well while
      # `FileUtils.remove_entry` is iterating the directory and removing all
      # its contained files and directories recursively, which could raise an
      # error.
      # Failing to remove the tmp directory could leave the `gpg-agent` process
      # running forever.
      #
      # 15 tries will never complete within the maximum time with exponential
      # backoff. So our limit is the runtime, not the number of tries.
      Retriable.retriable(max_elapsed_time: cleanup_time, base_interval: 0.1, tries: 15) do
        FileUtils.rm_rf(tmp_dir)
      end
    rescue StandardError => e
      raise CleanupError, e
    end

    def cleanup_time
      Gitlab::Runtime.sidekiq? ? BG_CLEANUP_RUNTIME_S : FG_CLEANUP_RUNTIME_S
    end

    def tmp_keychains_created
      Gitlab::Metrics.counter(:gpg_tmp_keychains_created_total, 'The number of temporary GPG keychains created')
    end

    def tmp_keychains_removed
      Gitlab::Metrics.counter(:gpg_tmp_keychains_removed_total, 'The number of temporary GPG keychains removed')
    end
  end
end
