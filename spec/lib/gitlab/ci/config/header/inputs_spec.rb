# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Ci::Config::Header::Inputs, feature_category: :pipeline_composition do
  let(:factory) do
    Gitlab::Config::Entry::Factory.new(described_class)
      .value(inputs_hash)
      .with(key: :inputs)
  end

  subject(:inputs) { factory.create! }

  before do
    Gitlab::Ci::Config::FeatureFlags.with_actor(nil) { inputs.compose! }
  end

  context 'with valid inputs' do
    let(:inputs_hash) do
      {
        environment: {
          options: %w[development staging production]
        },
        region: {
          options: %w[us eu asia]
        }
      }
    end

    it { is_expected.to be_valid }
  end

  context 'with undefined input references' do
    let(:inputs_hash) do
      {
        environment: {
          options: %w[development production]
        },
        resource_tier: {
          rules: [
            {
              if: '$[[ inputs.undefined_input ]] == "value"',
              options: %w[small medium],
              default: 'small'
            }
          ]
        }
      }
    end

    it 'is invalid' do
      expect(inputs).not_to be_valid
      expect(inputs.errors.first).to include('rule[0] references undefined inputs: undefined_input')
    end

    context 'when ci_validate_spec_input_rules is disabled' do
      it 'does not report the undefined input' do
        stub_feature_flags(ci_validate_spec_input_rules: false)

        entry = Gitlab::Ci::Config::FeatureFlags.with_actor(nil) { factory.create!.tap(&:compose!) }

        expect(entry.errors).not_to include(match(/references undefined inputs/))
      end
    end
  end

  context 'with circular dependencies' do
    let(:inputs_hash) do
      {
        region: {
          rules: [{ if: '$[[ inputs.size ]] == "large"', options: %w[us], default: 'us' }]
        },
        size: {
          rules: [{ if: '$[[ inputs.region ]] == "us"', options: %w[large], default: 'large' }]
        }
      }
    end

    it 'is invalid' do
      expect(inputs).not_to be_valid
      expect(inputs.errors).to include(match(/circular dependency detected/))
    end
  end

  context 'with malformed rules' do
    shared_examples 'reports a validation error instead of raising' do
      let(:inputs_hash) do
        {
          region: { options: %w[us eu] },
          size: { rules: rules }
        }
      end

      it 'is invalid' do
        expect(inputs).not_to be_valid
        expect(inputs.errors).not_to be_empty
      end
    end

    context 'when rules is a string' do
      let(:rules) { 'foo' }

      it_behaves_like 'reports a validation error instead of raising'
    end

    context 'when a rule is a string' do
      let(:rules) { ['foo'] }

      it_behaves_like 'reports a validation error instead of raising'
    end
  end

  describe 'inputs count limit' do
    let(:limit) { described_class::MAX_INPUTS }
    let(:inputs_hash) { {} }

    subject(:composed_inputs) do
      Gitlab::Ci::Config::FeatureFlags.with_actor(nil) do
        Gitlab::Config::Entry::Factory.new(described_class)
          .value(Array.new(input_count) { |i| [:"input_#{i}", {}] }.to_h)
          .with(key: :inputs)
          .create!
          .tap(&:compose!)
      end
    end

    before do
      allow(Gitlab::AppJsonLogger).to receive(:info)
    end

    context 'when the number of inputs is at the limit' do
      let(:input_count) { limit }

      it 'is valid and does not log' do
        expect(composed_inputs).to be_valid
        expect(Gitlab::AppJsonLogger).not_to have_received(:info)
      end
    end

    context 'when the number of inputs is above the limit' do
      let(:input_count) { limit + 1 }

      it 'is invalid' do
        expect(composed_inputs).not_to be_valid
        expect(composed_inputs.errors).to include(match(/cannot declare more than #{limit} inputs/))
      end

      it 'does not compose the inputs' do
        expect(composed_inputs.descendants).to be_empty
      end

      it 'logs the number of inputs' do
        composed_inputs

        expect(Gitlab::AppJsonLogger).to have_received(:info).with(
          a_hash_including(
            message: 'spec:inputs declares more inputs than the limit',
            inputs_count: limit + 1,
            inputs_limit: limit
          )
        )
      end

      context 'when ci_limit_spec_inputs_count is disabled' do
        before do
          stub_feature_flags(ci_limit_spec_inputs_count: false)
        end

        it 'is valid and still logs' do
          expect(composed_inputs).to be_valid
          expect(Gitlab::AppJsonLogger).to have_received(:info).with(
            a_hash_including(inputs_count: limit + 1)
          )
        end

        it 'composes the inputs' do
          expect(composed_inputs.descendants.size).to eq(limit + 1)
        end
      end
    end
  end
end
