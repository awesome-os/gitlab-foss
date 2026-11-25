# frozen_string_literal: true

require 'fast_spec_helper'

RSpec.describe Gitlab::Database::LoadBalancing::Lsn, feature_category: :database do
  describe '.parse' do
    it 'reads the high and low 32 bits' do
      expect(described_class.parse('16/B374D848').value).to eq((0x16 << 32) + 0xB374D848)
    end

    it 'is nil for text that is not an LSN', :aggregate_failures do
      [
        'junk', '', nil, '16', '16/', '/B374D848', 'g/1', '1/2/3',
        '-1/0', '+A/0', '0x1/0', '1_0/0', ' 1/0', '1/0 ', "1/0\n", '0/100000000', '123456789/0'
      ].each do |text|
        expect(described_class.parse(text)).to be_nil
      end
    end
  end

  describe 'comparison' do
    it 'orders by the high bits before the low bits', :aggregate_failures do
      expect(described_class.parse('1/0')).to be > described_class.parse('0/FFFFFFFF')
      expect(described_class.parse('0/10')).to be > described_class.parse('0/9')
      expect(described_class.parse('A/0').value).to eq(described_class.parse('a/0').value)
    end

    it 'is not equal to something that is not an LSN', :aggregate_failures do
      expect({ 'main' => described_class.parse('0/1') }.value?(nil)).to be(false)
      expect(described_class.parse('0/1')).not_to eq('0/1')
    end
  end

  describe '#to_s' do
    it 'is the text it was read from' do
      expect(described_class.parse('16/B374D848').to_s).to eq('16/B374D848')
    end
  end
end
