# frozen_string_literal: true

RSpec.describe QA::Resource::UserGPG do
  subject(:resource) { described_class.new }

  describe '#fabricate_via_api!' do
    let(:error) { QA::Resource::Errors::ResourceFabricationFailedError.new(message) }

    before do
      allow(resource).to receive(:api_post).and_raise(error)
    end

    context 'when the key has already been taken' do
      let(:message) do
        'Fabrication of QA::Resource::UserGPG using the API failed (400) with ' \
          '`{"message":{"fingerprint":["has already been taken"]}}`.'
      end

      it 'returns the resource' do
        expect(resource.fabricate_via_api!).to be(resource)
      end
    end

    context 'when fabrication fails for another reason' do
      let(:message) do
        'Fabrication of QA::Resource::UserGPG using the API failed (500) with ' \
          '`{"message":"500 Internal Server Error"}`.'
      end

      it 'raises the original error' do
        expect { resource.fabricate_via_api! }.to raise_error do |raised|
          expect(raised).to be(error)
          expect(raised.message).to eq(message)
        end
      end
    end
  end
end
