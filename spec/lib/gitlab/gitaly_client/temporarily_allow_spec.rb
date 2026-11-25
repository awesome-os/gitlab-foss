# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::GitalyClient::TemporarilyAllow, feature_category: :gitaly do
  subject(:allower) { Class.new { extend Gitlab::GitalyClient::TemporarilyAllow } }

  shared_examples 'a temporary allowance' do
    it 'is not allowed by default' do
      expect(allower.temporarily_allowed?(:key)).to be(false)
    end

    it 'is allowed inside the block only' do
      allower.temporarily_allow(:key) do
        expect(allower.temporarily_allowed?(:key)).to be(true)
        expect(allower.temporarily_allowed?(:other_key)).to be(false)
      end

      expect(allower.temporarily_allowed?(:key)).to be(false)
    end

    it 'stays allowed until the outermost block ends' do
      allower.temporarily_allow(:key) do
        allower.temporarily_allow(:key) { nil }

        expect(allower.temporarily_allowed?(:key)).to be(true)
      end
    end

    it 'ends the allowance when the block raises' do
      expect { allower.temporarily_allow(:key) { raise 'boom' } }.to raise_error('boom')

      expect(allower.temporarily_allowed?(:key)).to be(false)
    end
  end

  context 'with a request store', :request_store do
    it_behaves_like 'a temporary allowance'

    it 'keeps the allowance in the request store' do
      allower.temporarily_allow(:key) do
        expect(Gitlab::SafeRequestStore[:temporarily_allow]).to eq(key: 1)
      end
    end
  end

  context 'without a request store' do
    it_behaves_like 'a temporary allowance'
  end
end
