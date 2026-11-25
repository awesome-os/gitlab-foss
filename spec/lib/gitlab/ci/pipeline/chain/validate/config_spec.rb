# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Ci::Pipeline::Chain::Validate::Config, feature_category: :pipeline_composition do
  let(:project) { create(:project) }
  let(:pipeline) { build_stubbed(:ci_pipeline, project: project, source: :push) }
  let(:inputs) { {} }

  let(:command) do
    Gitlab::Ci::Pipeline::Chain::Command.new(project: project, inputs: inputs)
  end

  let(:step) { described_class.new(pipeline, command) }

  describe '#perform!' do
    context 'when params contain more inputs than the inputs limit (20)' do
      let(:inputs) do
        {
          'string' => 'bar',
          boolean: true
        }
      end

      before do
        stub_const('Ci::Pipeline::INPUTS_LIMIT', 1)
      end

      it 'raises an error' do
        step.perform!

        expect(pipeline.errors.full_messages).to include('There cannot be more than 1 inputs')
      end
    end

    context 'when checking the size of input values' do
      before do
        stub_const('Ci::Pipeline::INPUT_VALUE_SIZE_LIMIT', 10)
      end

      context 'when every value is within the limit' do
        let(:inputs) { { 'string' => 'abcdefgh', 'array' => %w[a b] } }

        it 'does not add an error' do
          step.perform!

          expect(pipeline.errors).to be_empty
        end
      end

      context 'when a string value is longer than the limit' do
        let(:inputs) { { 'short' => 'a', 'long' => 'a' * 20 } }

        it 'adds an error naming the input', :aggregate_failures do
          step.perform!

          expect(pipeline.errors.full_messages)
            .to contain_exactly('The value of input `long` cannot be larger than 10 B as JSON')
          expect(step.break?).to be(true)
        end
      end

      context 'when an array value serializes to more than the limit' do
        let(:inputs) { { 'array' => %w[one two three] } }

        it 'adds an error naming the input' do
          step.perform!

          expect(pipeline.errors.full_messages)
            .to contain_exactly('The value of input `array` cannot be larger than 10 B as JSON')
        end
      end

      context 'when a value has multi-byte characters that pass the limit in bytes' do
        let(:inputs) { { 'emoji' => '😀' * 4 } } # 4 characters, 16 bytes

        it 'adds an error naming the input' do
          step.perform!

          expect(pipeline.errors.full_messages)
            .to contain_exactly(a_string_including('The value of input `emoji`'))
        end
      end

      context 'when a string value is within the limit but its escaped form is not' do
        let(:inputs) { { 'multiline' => "\n" * 8 } } # 8 characters, serialized as 18

        it 'adds an error naming the input' do
          step.perform!

          expect(pipeline.errors.full_messages)
            .to contain_exactly(a_string_including('The value of input `multiline`'))
        end
      end

      context 'when the ci_pipeline_input_value_size_limit feature flag is disabled' do
        let(:inputs) { { 'long' => 'a' * 20 } }

        before do
          stub_feature_flags(ci_pipeline_input_value_size_limit: false)
        end

        it 'does not add an error' do
          step.perform!

          expect(pipeline.errors).to be_empty
        end
      end
    end
  end
end
