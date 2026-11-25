# frozen_string_literal: true

module Gitlab
  module MobilePush
    # Seals a push's content for one device: the version-2 envelope the GitLab
    # mobile app's notification extension opens. AES-256-GCM under the key the
    # device registered (`content_key`), with additional authenticated data
    # binding the ciphertext to the device token it is sent to and to the time
    # it was sealed, so a captured payload neither opens on another device nor
    # after the delivery window (the app refuses an `iat` older than 3900 s).
    class EncryptedContent
      ALGORITHM = 'A256GCM'
      VERSION = 2
      NONCE_BYTES = 12
      TAG_BYTES = 16

      # @return [String] the `aad` the extension rebuilds: the contract version,
      #   the device token as registered (lowercase hex) and the issue time,
      #   newline joined
      def self.additional_data(device_token:, issued_at:)
        "gitlab-mobile-push/#{VERSION}\n#{device_token.downcase}\n#{issued_at}"
      end

      # @return [Hash] the `content` dictionary of the APNs `gitlab` object:
      #   `{ alg:, v:, iat:, ciphertext: }`, the ciphertext being strict base64
      #   of nonce || ciphertext || tag (CryptoKit's `SealedBox.combined`)
      def self.seal(plaintext, key:, device_token:, issued_at: Time.current.to_i)
        cipher = OpenSSL::Cipher.new('aes-256-gcm').encrypt
        cipher.key = key
        nonce = SecureRandom.random_bytes(NONCE_BYTES)
        cipher.iv = nonce
        cipher.auth_data = additional_data(device_token: device_token, issued_at: issued_at)

        ciphertext = cipher.update(plaintext) + cipher.final

        {
          alg: ALGORITHM,
          v: VERSION,
          iat: issued_at,
          ciphertext: Base64.strict_encode64(nonce + ciphertext + cipher.auth_tag(TAG_BYTES))
        }
      end
    end
  end
end
