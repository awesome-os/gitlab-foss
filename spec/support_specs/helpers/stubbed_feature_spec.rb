# frozen_string_literal: true

require 'spec_helper'

RSpec.describe StubbedFeature, feature_category: :tooling do
  describe '.persisted_name?' do
    let(:flag) { :stubbed_feature_spec_flag }

    before do
      stub_feature_flag_definition(flag)
    end

    it 'matches persisted_names for every feature definition' do
      stub_feature_flags(flag => true)

      persisted = Feature.persisted_names
      names = Feature::Definition.definitions.keys + [flag, 'unknown_flag']

      expect(persisted).to include(flag.to_s)
      expect(names.map { |name| Feature.persisted_name?(name) })
        .to eq(names.map { |name| persisted.include?(name.to_s) })
    end

    it 'accepts strings and symbols' do
      Feature.enable(flag)

      expect(Feature.persisted_name?(flag)).to be(true)
      expect(Feature.persisted_name?(flag.to_s)).to be(true)
    end

    it 'returns false once the flag is removed' do
      Feature.enable(flag)
      Feature.remove(flag)

      expect(Feature.persisted_name?(flag)).to be(false)
    end

    it 'does not build the set of persisted names' do
      expect(Feature).not_to receive(:persisted_names)

      Feature.persisted_name?(flag)
    end

    context 'when the flipper adapter is not the stubbed one' do
      before do
        allow(Feature).to receive(:flipper).and_return(Flipper.new(Flipper::Adapters::Memory.new))
      end

      it 'falls back to persisted_names' do
        expect(Feature).to receive(:persisted_names).and_call_original

        expect(Feature.persisted_name?(flag)).to be(false)
      end
    end
  end
end
