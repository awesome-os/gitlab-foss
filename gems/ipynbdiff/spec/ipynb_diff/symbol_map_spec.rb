# frozen_string_literal: true

require_relative '../test_helper'

describe IpynbDiff::SymbolMap do
  def res(*cases)
    cases&.to_h || []
  end

  describe '.parse' do
    subject(:symbol_map) { described_class.parse(JSON.pretty_generate(source)) }

    context 'when object has blank key' do
      let(:source) { { "": { "": 5 } } }

      it { is_expected.to match_array(res([".", 2], ["..", 3])) }
    end

    context 'when object is empty' do
      let(:source) { {} }

      it { is_expected.to be_empty }
    end

    context 'when object is empty array' do
      let(:source) { [] }

      it { is_expected.to be_empty }
    end

    context 'when object has inner object and number' do
      let(:source) { { obj1: { obj2: 1 } } }

      it { is_expected.to match_array(res(['.obj1', 2], ['.obj1.obj2', 3])) }
    end

    context 'when a number is directly followed by a newline' do
      let(:source) { { obj1: { obj2: 1 }, obj3: [2], obj4: 3.5, obj5: -4 } }

      it 'counts the newline' do
        expect(symbol_map).to match_array(
          res(['.obj1', 2],
            ['.obj1.obj2', 3],
            ['.obj3', 5],
            ['.obj3.0', 6],
            ['.obj4', 8],
            ['.obj5', 9])
        )
      end
    end

    context 'when object has inner object and number, string and array with object' do
      let(:source) { { obj1: { obj2: [123, 2, true], obj3: "hel\nlo", obj4: true, obj5: 123, obj6: 'a' } } }

      specify do
        expect(symbol_map).to match_array(
          res(['.obj1', 2],
            ['.obj1.obj2', 3],
            ['.obj1.obj2.0', 4],
            ['.obj1.obj2.1', 5],
            ['.obj1.obj2.2', 6],
            ['.obj1.obj3', 8],
            ['.obj1.obj4', 9],
            ['.obj1.obj5', 10],
            ['.obj1.obj6', 11])
        )
      end
    end
  end
end
