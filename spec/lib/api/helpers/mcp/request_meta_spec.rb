# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::Helpers::Mcp::RequestMeta, feature_category: :mcp_server do
  let(:version_key) { described_class::PROTOCOL_VERSION_KEY }
  let(:capabilities_key) { described_class::CLIENT_CAPABILITIES_KEY }

  def meta_for(meta)
    described_class.from_jsonrpc_params({ '_meta' => meta })
  end

  shared_examples 'a legacy request' do
    it 'is not modern, not unsupported and has no version', :aggregate_failures do
      expect(request_meta.protocol_version).to be_nil
      expect(request_meta).not_to be_modern
      expect(request_meta).not_to be_unsupported_protocol_version
    end
  end

  describe '.from_jsonrpc_params' do
    context 'with Array params' do
      let(:request_meta) { described_class.from_jsonrpc_params([{ '_meta' => { version_key => '2026-07-28' } }]) }

      it_behaves_like 'a legacy request'
    end

    context 'with nil params' do
      let(:request_meta) { described_class.from_jsonrpc_params(nil) }

      it_behaves_like 'a legacy request'
    end

    context 'with params that have no _meta' do
      let(:request_meta) { described_class.from_jsonrpc_params({ 'name' => 'ping' }) }

      it_behaves_like 'a legacy request'
    end

    context 'with a String _meta' do
      let(:request_meta) { meta_for('not-a-hash') }

      it_behaves_like 'a legacy request'
    end

    context 'with an Array _meta' do
      let(:request_meta) { meta_for([version_key, '2026-07-28']) }

      it_behaves_like 'a legacy request'
    end

    context 'with an empty _meta' do
      let(:request_meta) { meta_for({}) }

      it_behaves_like 'a legacy request'
    end

    context 'with symbol keys on the params' do
      let(:request_meta) { described_class.from_jsonrpc_params({ _meta: { version_key => '2026-07-28' } }) }

      it 'reads _meta' do
        expect(request_meta.protocol_version).to eq('2026-07-28')
      end
    end

    context 'with symbol keys inside _meta' do
      let(:request_meta) { meta_for({ version_key.to_sym => '2026-07-28' }) }

      it 'reads them' do
        expect(request_meta.protocol_version).to eq('2026-07-28')
      end
    end
  end

  describe 'a handshake version' do
    let(:request_meta) { meta_for({ version_key => '2025-06-18' }) }

    it 'is neither modern nor unsupported', :aggregate_failures do
      expect(request_meta.protocol_version).to eq('2025-06-18')
      expect(request_meta).not_to be_modern
      expect(request_meta).not_to be_unsupported_protocol_version
    end
  end

  describe 'a stateless version' do
    context 'with client capabilities' do
      let(:request_meta) { meta_for({ version_key => '2026-07-28', capabilities_key => { 'roots' => {} } }) }

      it 'is modern and complete', :aggregate_failures do
        expect(request_meta).to be_modern
        expect(request_meta).not_to be_unsupported_protocol_version
        expect(request_meta).not_to be_client_capabilities_missing
      end
    end

    context 'with empty client capabilities' do
      let(:request_meta) { meta_for({ version_key => '2026-07-28', capabilities_key => {} }) }

      it 'counts them as present' do
        expect(request_meta).not_to be_client_capabilities_missing
      end
    end

    context 'without client capabilities' do
      let(:request_meta) { meta_for({ version_key => '2026-07-28' }) }

      it 'reports them as missing' do
        expect(request_meta).to be_client_capabilities_missing
      end
    end

    context 'with nil client capabilities' do
      let(:request_meta) { meta_for({ version_key => '2026-07-28', capabilities_key => nil }) }

      it 'reports them as missing' do
        expect(request_meta).to be_client_capabilities_missing
      end
    end
  end

  describe 'an unknown version' do
    let(:request_meta) { meta_for({ version_key => '2099-01-01' }) }

    it 'is unsupported and not modern', :aggregate_failures do
      expect(request_meta.protocol_version).to eq('2099-01-01')
      expect(request_meta).to be_unsupported_protocol_version
      expect(request_meta).not_to be_modern
    end
  end
end
