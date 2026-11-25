# frozen_string_literal: true

module Authn
  module OauthApplications
    # Fetches and validates the Client ID Metadata Document that an OAuth client
    # uses as its client_id. See https://datatracker.ietf.org/doc/draft-ietf-oauth-client-id-metadata-document/
    class FetchClientMetadataDocumentService
      include Gitlab::Loggable

      MAX_DOCUMENT_BYTES = 64.kilobytes
      TIMEOUT = 5.seconds
      LOOPBACK_HOSTS = %w[localhost 127.0.0.1 [::1]].freeze
      SECRET_KEYS = %w[client_secret client_secret_expires_at].freeze
      # The same limits as Dynamic Client Registration: both take these values from an anonymous client.
      MAX_CLIENT_NAME_LENGTH = 199
      MAX_REDIRECT_URIS = 100
      MAX_REDIRECT_URI_LENGTH = 2048

      def initialize(url)
        @url = url.to_s
      end

      def execute
        url_error = validate_url
        return error(url_error, :invalid_url) if url_error

        response = Gitlab::HTTP.get(
          url,
          allow_local_requests: false,
          dns_rebinding_protection_enabled: true,
          follow_redirects: false,
          max_bytes: MAX_DOCUMENT_BYTES,
          timeout: TIMEOUT.to_i,
          headers: { 'Accept' => 'application/json' }
        )
        return fetch_failed("HTTP #{response.code}") unless response.code == 200

        document = Gitlab::Json::SafeParser.parse(response.body.to_s)
        return error('is not a JSON object', :invalid_document) unless document.is_a?(Hash)

        document_error = validate_document(document)
        return error(document_error, :invalid_document) if document_error

        ServiceResponse.success(
          payload: { client_name: document['client_name'], redirect_uris: document['redirect_uris'] }
        )
      rescue *Gitlab::HTTP::HTTP_ERRORS, Zlib::Error => e
        fetch_failed(e.class.name)
      rescue JSON::ParserError
        error('is not valid JSON', :invalid_document)
      end

      private

      attr_reader :url

      def validate_url
        return 'is too long' if url.bytesize > ::Authn::OauthApplication::CIMD_URL_MAX_BYTES

        uri = URI.parse(url)
        segments = uri.path.to_s.split('/')

        return 'must use https' unless uri.scheme == 'https' && uri.host.present?
        return 'must have a path other than /' if uri.path.blank? || uri.path == '/'
        return 'must not contain dot path segments' if segments.include?('.') || segments.include?('..')
        return 'must not contain a fragment' unless uri.fragment.nil?

        'must not contain credentials' unless uri.userinfo.nil?
      rescue URI::InvalidURIError
        'is not a valid URL'
      end

      def validate_document(document)
        return 'client_id does not match the document URL' unless document['client_id'] == url

        secret_key = SECRET_KEYS.find { |key| document.key?(key) }
        return "must not contain #{secret_key}" if secret_key
        return 'must not contain both jwks and jwks_uri' if document.key?('jwks') && document.key?('jwks_uri')

        auth_method_error = validate_auth_methods(document)
        return auth_method_error if auth_method_error
        return 'client_name is missing' unless document['client_name'].is_a?(String) && document['client_name'].present?
        return 'client_name is too long' if document['client_name'].length > MAX_CLIENT_NAME_LENGTH

        validate_redirect_uris(document['redirect_uris'])
      end

      # @note GitLab only accepts public clients. With no auth method declared, the
      #   draft says to assume none.
      def validate_auth_methods(document)
        single = document['token_endpoint_auth_method']
        supported = document.fetch('token_endpoint_auth_methods_supported', [])
        methods = [single, *(supported.is_a?(Array) ? supported : [supported])].compact
        return 'token endpoint authentication methods must be strings' unless methods.all?(String)
        return 'token_endpoint_auth_methods_supported must be a list' unless supported.is_a?(Array)

        return if methods.empty?
        return 'must not use a client secret to authenticate' if methods.any? { |m| m.start_with?('client_secret') }

        'token endpoint authentication methods must include none' unless methods.include?('none')
      end

      def validate_redirect_uris(redirect_uris)
        unless redirect_uris.is_a?(Array) && redirect_uris.any? && redirect_uris.all?(String)
          return 'redirect_uris must be a non-empty list of strings'
        end

        return "redirect_uris must contain at most #{MAX_REDIRECT_URIS} URIs" if redirect_uris.size > MAX_REDIRECT_URIS

        if redirect_uris.any? { |uri| uri.length > MAX_REDIRECT_URI_LENGTH }
          return "each redirect URI must be at most #{MAX_REDIRECT_URI_LENGTH} characters"
        end

        invalid = redirect_uris.find { |redirect_uri| !valid_redirect_uri?(redirect_uri) }
        "redirect_uris contains an invalid URI: #{invalid}" if invalid
      end

      # @note Native clients use loopback or custom-scheme redirects (RFC 8252); other
      #   http redirects would send the authorization code over plain text.
      def valid_redirect_uri?(redirect_uri)
        uri = URI.parse(redirect_uri)
        return false unless uri.absolute? && uri.opaque.nil? && uri.fragment.nil?
        return LOOPBACK_HOSTS.include?(uri.host) if uri.scheme == 'http'
        return uri.host.present? if uri.scheme == 'https'

        %w[javascript data vbscript].exclude?(uri.scheme.downcase)
      rescue URI::InvalidURIError
        false
      end

      # @note The caller picks the URL, so the reason for a failed fetch is only logged:
      #   returning it would let them probe internal addresses.
      def fetch_failed(reason)
        Gitlab::AppLogger.info(build_structured_payload_labkit(
          message: 'Client ID Metadata Document fetch failed', cimd_url: url, failure_reason: reason
        ))

        error('could not be fetched', :fetch_failed)
      end

      def error(message, reason)
        ServiceResponse.error(message: "Client ID Metadata Document #{message}", reason: reason)
      end
    end
  end
end
