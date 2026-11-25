# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Database::Aggregation::ParameterizedDefinition, feature_category: :value_stream_management do
  let(:definition_class) do
    Class.new(Gitlab::Database::Aggregation::PartDefinition) do
      include Gitlab::Database::Aggregation::ParameterizedDefinition
    end
  end

  let(:definition) do
    definition_class.new(:foo, :string, nil, parameters: { bar: { type: :string } })
  end

  let(:definition_without_params) do
    definition_class.new(:foo, :string)
  end

  let(:array_definition) do
    definition_class.new(:foo, :string, nil, parameters: { bar: { type: :string, array: true } })
  end

  describe '#instance_key' do
    it 'returns simple value for non-parameterized definition' do
      expect(definition_without_params.instance_key({})).to eq('foo')
    end

    it 'returns simple value for request without params' do
      expect(definition.instance_key({})).to eq('foo')
    end

    context 'with scalar request parameters' do
      it 'returns identifier with parameters postfix' do
        expect(definition.instance_key(parameters: { bar: '42' })).to eq('foo_42')
      end

      it 'uses hashed identifier postfix if non-word param is present' do
        expect(definition.instance_key(parameters: { bar: '42.5' })).to eq('foo_7b713')
        expect(definition.instance_key(parameters: { bar: 'something long' })).to eq('foo_cb42e')
        expect(definition.instance_key(parameters: { bar: 'with_symbols;:"' })).to eq('foo_97763')
      end
    end

    context 'with array: true parameter' do
      it 'produces the same key for a single-element array and its scalar equivalent' do
        expect(array_definition.instance_key(parameters: { bar: ['42'] })).to eq('foo_42')
        expect(array_definition.instance_key(parameters: { bar: '42' })).to eq('foo_42')
      end

      it 'joins multi-element array values with underscore in the postfix' do
        expect(array_definition.instance_key(parameters: { bar: %w[success failed] })).to eq('foo_success_failed')
      end

      it 'uses hashed postfix when joined array values contain non-word characters' do
        expect(array_definition.instance_key(parameters: { bar: ['v1.0', 'v2.0'] })).to match(/\Afoo_[0-9a-f]{5}\z/)
      end

      it 'produces different keys for different array contents' do
        key1 = array_definition.instance_key(parameters: { bar: %w[success failed] })
        key2 = array_definition.instance_key(parameters: { bar: %w[failed success] })
        expect(key1).not_to eq(key2)
      end
    end

    context 'with multiple optional parameters' do
      let(:multi_param_definition) do
        definition_class.new(:foo, :string, nil,
          parameters: { bar: { type: :string }, baz: { type: :string } })
      end

      it 'includes all provided parameters prefixed with their names in the postfix' do
        expect(multi_param_definition.instance_key(parameters: { bar: '42', baz: '43' })).to eq('foo_bar_42_baz_43')
      end

      it 'skips parameters that were not provided' do
        expect(multi_param_definition.instance_key(parameters: { bar: '42' })).to eq('foo_bar_42')
        expect(multi_param_definition.instance_key(parameters: { baz: '43' })).to eq('foo_baz_43')
      end

      it 'produces different keys when the same value is provided for different parameters' do
        key1 = multi_param_definition.instance_key(parameters: { bar: '42' })
        key2 = multi_param_definition.instance_key(parameters: { baz: '42' })
        expect(key1).not_to eq(key2)
      end
    end
  end

  # Pins keys built by the engines' real parameter shapes. Response fields look values up by
  # these keys, so a change here breaks existing requests.
  describe '#instance_key with engine parameter shapes' do
    let(:click_house) { Gitlab::Database::Aggregation::ClickHouse }

    it 'keeps date bucket keys stable' do
      dimension = click_house::DateBucketDimension.new(:created_at, :date)

      expect(dimension.instance_key(parameters: { granularity: '30d' })).to eq('created_at_granularity_30d')
      expect(dimension.instance_key(parameters: { granularity: '30d', origin: Time.utc(2026, 1, 1) }))
        .to eq('created_at_402f0')
    end

    it 'keeps quantile keys stable' do
      quantile = click_house::Quantile.new(:duration, :float, nil, parameters: { quantile: { type: :float } })

      expect(quantile.instance_key(parameters: { quantile: 0.5 })).to eq('duration_quantile_d2cba')
    end

    it 'keeps parameterized count keys stable' do
      count = click_house::Count.new(parameters: {
        source: { type: :string, array: true }, status: { type: :string, array: true }
      })

      expect(count.instance_key(parameters: { source: %w[push web] })).to eq('total_count_source_push_web')
    end
  end
end
