# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Authn::OauthApplications::FetchClientMetadataDocumentService, feature_category: :system_access do
  include StubRequests

  let(:document_url) { 'https://client.example.com/oauth/client.json' }
  let(:url) { document_url }
  let(:document) do
    {
      client_id: document_url,
      client_name: 'Example MCP client',
      redirect_uris: ['http://127.0.0.1:33418/callback', 'https://client.example.com/callback'],
      token_endpoint_auth_method: 'none'
    }
  end

  let(:body) { document.to_json }
  let(:status) { 200 }

  subject(:result) { described_class.new(url).execute }

  before do
    stub_full_request(document_url, port: 443).to_return(status: status, body: body,
      headers: { 'Content-Type' => 'application/json' })
  end

  shared_examples 'a rejected document' do |reason, message|
    it 'returns an error', :aggregate_failures do
      expect(result).to be_error
      expect(result.reason).to eq(reason)
      expect(result.message).to eq("Client ID Metadata Document #{message}")
    end
  end

  shared_examples 'a failed fetch' do |failure_reason|
    it_behaves_like 'a rejected document', :fetch_failed, 'could not be fetched'

    it 'logs why without returning it' do
      allow(Gitlab::AppLogger).to receive(:info).and_call_original

      result

      expect(Gitlab::AppLogger).to have_received(:info).with(hash_including(
        'message' => 'Client ID Metadata Document fetch failed', 'cimd_url' => url, 'failure_reason' => failure_reason
      ))
    end
  end

  it 'returns the client name and redirect URIs', :aggregate_failures do
    expect(result).to be_success
    expect(result.payload).to eq(client_name: 'Example MCP client', redirect_uris: document[:redirect_uris])
  end

  context 'with custom-scheme redirect URIs for a native client' do
    let(:document) do
      super().merge(redirect_uris: ['cursor://anysphere.cursor-mcp/oauth/callback', 'com.example.app:/callback'])
    end

    it 'accepts them' do
      expect(result).to be_success
    end
  end

  context 'with limits on values from the document' do
    let(:longest_uri) { "https://client.example.com/#{'a' * 2021}" }
    let(:document) do
      super().merge(client_name: 'a' * 199,
        redirect_uris: [longest_uri, *Array.new(99) { |i| "https://client.example.com/#{i}" }])
    end

    it 'accepts values at the limits' do
      expect(result).to be_success
    end
  end

  describe 'URL validation' do
    using RSpec::Parameterized::TableSyntax

    where(:invalid_url, :message) do
      'http://client.example.com/client.json'            | 'must use https'
      'https://client.example.com'                       | 'must have a path other than /'
      'https://client.example.com/'                      | 'must have a path other than /'
      'https://client.example.com/a/../client.json'      | 'must not contain dot path segments'
      'https://client.example.com/./client.json'         | 'must not contain dot path segments'
      'https://client.example.com/client.json#fragment'  | 'must not contain a fragment'
      'https://user:pass@client.example.com/client.json' | 'must not contain credentials'
      'https://client.example.com/client json'           | 'is not a valid URL'
    end

    with_them do
      let(:url) { invalid_url }

      before do
        allow(Gitlab::HTTP).to receive(:get)
      end

      it_behaves_like 'a rejected document', :invalid_url, params[:message]

      it 'does not fetch the URL' do
        result

        expect(Gitlab::HTTP).not_to have_received(:get)
      end
    end

    context 'when the URL is longer than the cimd_url column allows' do
      let(:url) { "https://client.example.com/#{'ク' * 683}" }

      it_behaves_like 'a rejected document', :invalid_url, 'is too long'
    end
  end

  describe 'fetching' do
    it 'does not follow redirects, and limits the response size and time' do
      allow(Gitlab::HTTP).to receive(:get).and_call_original

      result

      expect(Gitlab::HTTP).to have_received(:get)
        .with(url, hash_including(follow_redirects: false, max_bytes: 64.kilobytes, timeout: 5))
    end

    it 'blocks local addresses and DNS rebinding whatever the admin settings say' do
      stub_application_setting(allow_local_requests_from_web_hooks_and_services: true,
        dns_rebinding_protection_enabled: false)
      allow(Gitlab::HTTP).to receive(:get).and_call_original

      result

      expect(Gitlab::HTTP).to have_received(:get)
        .with(url, hash_including(allow_local_requests: false, dns_rebinding_protection_enabled: true))
    end

    context 'when the compressed body is corrupt' do
      # WebMock skips Net::HTTP's inflater, which raises this for a bad gzip body.
      before do
        allow(Gitlab::HTTP).to receive(:get).and_raise(Zlib::DataError)
      end

      it_behaves_like 'a failed fetch', 'Zlib::DataError'
    end

    context 'when the URL resolves to a local address and local requests are allowed' do
      before do
        stub_application_setting(allow_local_requests_from_web_hooks_and_services: true)
        stub_full_request(url, ip_address: '127.0.0.1', port: 443).to_return(status: 200, body: body)
      end

      it_behaves_like 'a failed fetch', 'Gitlab::HTTP_V2::BlockedUrlError'
    end

    context 'when the server redirects' do
      let(:status) { 302 }

      it_behaves_like 'a failed fetch', 'HTTP 302'
    end

    context 'when the server returns an error' do
      let(:status) { 404 }

      it_behaves_like 'a failed fetch', 'HTTP 404'
    end

    context 'when the URL resolves to a local address' do
      before do
        stub_full_request(url, ip_address: '127.0.0.1', port: 443).to_return(status: 200, body: body)
      end

      it_behaves_like 'a failed fetch', 'Gitlab::HTTP_V2::BlockedUrlError'
    end

    context 'when the document is larger than the limit' do
      let(:body) { document.merge(padding: 'a' * 64.kilobytes).to_json }

      it_behaves_like 'a failed fetch', 'Gitlab::HTTP_V2::ResponseSizeTooLarge'
    end

    context 'when the request times out' do
      before do
        stub_full_request(url, port: 443).to_timeout
      end

      it_behaves_like 'a failed fetch', 'Net::OpenTimeout'
    end
  end

  describe 'document validation' do
    context 'when the body is not JSON' do
      let(:body) { 'not json' }

      it_behaves_like 'a rejected document', :invalid_document, 'is not valid JSON'
    end

    context 'when the body is not a JSON object' do
      let(:body) { '[]' }

      it_behaves_like 'a rejected document', :invalid_document, 'is not a JSON object'
    end

    context 'when client_id does not match the URL' do
      let(:document) { super().merge(client_id: 'https://other.example.com/oauth/client.json') }

      it_behaves_like 'a rejected document', :invalid_document, 'client_id does not match the document URL'
    end

    context 'when no token endpoint authentication method is declared' do
      let(:document) { super().except(:token_endpoint_auth_method) }

      it 'assumes none' do
        expect(result).to be_success
      end
    end

    context 'when token_endpoint_auth_methods_supported includes none' do
      let(:document) do
        super().except(:token_endpoint_auth_method)
          .merge(token_endpoint_auth_methods_supported: %w[none private_key_jwt])
      end

      it 'accepts it' do
        expect(result).to be_success
      end
    end

    context 'when token_endpoint_auth_method uses a client secret' do
      let(:document) { super().merge(token_endpoint_auth_method: 'client_secret_basic') }

      it_behaves_like 'a rejected document', :invalid_document, 'must not use a client secret to authenticate'
    end

    context 'when token_endpoint_auth_methods_supported includes a client secret method' do
      let(:document) { super().merge(token_endpoint_auth_methods_supported: %w[none client_secret_post]) }

      it_behaves_like 'a rejected document', :invalid_document, 'must not use a client secret to authenticate'
    end

    context 'when the declared authentication methods do not include none' do
      let(:document) { super().merge(token_endpoint_auth_method: 'private_key_jwt') }

      it_behaves_like 'a rejected document', :invalid_document,
        'token endpoint authentication methods must include none'
    end

    context 'when token_endpoint_auth_methods_supported is not a list' do
      let(:document) { super().merge(token_endpoint_auth_methods_supported: 'none') }

      it_behaves_like 'a rejected document', :invalid_document,
        'token_endpoint_auth_methods_supported must be a list'
    end

    context 'when a token endpoint authentication method is not a string' do
      let(:document) { super().merge(token_endpoint_auth_methods_supported: ['none', 1]) }

      it_behaves_like 'a rejected document', :invalid_document,
        'token endpoint authentication methods must be strings'
    end

    context 'when the document contains a client_secret' do
      let(:document) { super().merge(client_secret: 'secret') }

      it_behaves_like 'a rejected document', :invalid_document, 'must not contain client_secret'
    end

    context 'when the document contains client_secret_expires_at' do
      let(:document) { super().merge(client_secret_expires_at: 0) }

      it_behaves_like 'a rejected document', :invalid_document, 'must not contain client_secret_expires_at'
    end

    context 'when the document contains both jwks and jwks_uri' do
      let(:document) { super().merge(jwks: { keys: [] }, jwks_uri: 'https://client.example.com/jwks.json') }

      it_behaves_like 'a rejected document', :invalid_document, 'must not contain both jwks and jwks_uri'
    end

    context 'when client_name is missing' do
      let(:document) { super().except(:client_name) }

      it_behaves_like 'a rejected document', :invalid_document, 'client_name is missing'
    end

    context 'when client_name is too long' do
      let(:document) { super().merge(client_name: 'a' * 200) }

      it_behaves_like 'a rejected document', :invalid_document, 'client_name is too long'
    end

    context 'when there are too many redirect URIs' do
      let(:document) { super().merge(redirect_uris: Array.new(101) { |i| "https://client.example.com/#{i}" }) }

      it_behaves_like 'a rejected document', :invalid_document, 'redirect_uris must contain at most 100 URIs'
    end

    context 'when a redirect URI is too long' do
      let(:document) { super().merge(redirect_uris: ["https://client.example.com/#{'a' * 2048}"]) }

      it_behaves_like 'a rejected document', :invalid_document,
        'each redirect URI must be at most 2048 characters'
    end

    context 'when redirect_uris is missing' do
      let(:document) { super().except(:redirect_uris) }

      it_behaves_like 'a rejected document', :invalid_document, 'redirect_uris must be a non-empty list of strings'
    end

    context 'when redirect_uris is empty' do
      let(:document) { super().merge(redirect_uris: []) }

      it_behaves_like 'a rejected document', :invalid_document, 'redirect_uris must be a non-empty list of strings'
    end

    context 'when a redirect URI uses http with a non-loopback host' do
      let(:document) { super().merge(redirect_uris: ['http://client.example.com/callback']) }

      it_behaves_like 'a rejected document', :invalid_document,
        'redirect_uris contains an invalid URI: http://client.example.com/callback'
    end

    context 'when a redirect URI uses a forbidden scheme' do
      let(:document) { super().merge(redirect_uris: ['javascript:alert(1)']) }

      it_behaves_like 'a rejected document', :invalid_document,
        'redirect_uris contains an invalid URI: javascript:alert(1)'
    end

    context 'when a redirect URI has a fragment' do
      let(:document) { super().merge(redirect_uris: ['https://client.example.com/callback#done']) }

      it_behaves_like 'a rejected document', :invalid_document,
        'redirect_uris contains an invalid URI: https://client.example.com/callback#done'
    end

    context 'with a malformed redirect URI' do
      using RSpec::Parameterized::TableSyntax

      where(:redirect_uri) do
        ['localhost:3000/cb', 'https:foo', 'https:///cb']
      end

      with_them do
        let(:document) { super().merge(redirect_uris: [redirect_uri]) }

        it_behaves_like 'a rejected document', :invalid_document,
          "redirect_uris contains an invalid URI: #{params[:redirect_uri]}"
      end
    end

    context 'when a redirect URI cannot be parsed' do
      let(:document) { super().merge(redirect_uris: ['https://client.example.com/call back']) }

      it_behaves_like 'a rejected document', :invalid_document,
        'redirect_uris contains an invalid URI: https://client.example.com/call back'
    end
  end
end
