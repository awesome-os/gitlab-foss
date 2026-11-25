# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::Analytics::Aggregation::EngineResponseType, feature_category: :database do
  let(:engine_class) do
    Gitlab::Database::Aggregation::Engine.build do
      def self.metrics_mapping
        {
          metric: Gitlab::Database::Aggregation::ClickHouse::MetricDefinition,
          quantile: Gitlab::Database::Aggregation::ClickHouse::Quantile,
          ratio: Gitlab::Database::Aggregation::ClickHouse::Ratio
        }
      end

      def self.dimensions_mapping
        {
          column: Gitlab::Database::Aggregation::ClickHouse::DimensionDefinition,
          traversal_path: Gitlab::Database::Aggregation::ClickHouse::TraversalPathDimension
        }
      end

      def self.filters_mapping
        {}
      end

      dimensions do
        column :user_id, :integer
        traversal_path :group_id, :integer, -> { Arel.sql('traversal_path') },
          association: { preloader: Preloaders::GroupPolicyPreloader }
      end

      metrics do
        metric :total, :integer, description: 'Total count'
        metric :events, :integer, description: 'Event count', parameters: {
          event: { type: :string, array: true, description: 'Only count the given events.',
                   experiment: { milestone: '19.6' } },
          label: { type: :string, array: true, max_size: 5 },
          scope: { type: :string, description: 'Scope to count.' }
        }
        metric :"duration.max", :integer, ->(_params) { Arel.sql('max(duration)') }, description: 'Maximum duration'
        metric :"duration.mean", :float, ->(_params) { Arel.sql('avg(duration)') }, description: 'Mean duration'
        quantile :"duration.quantile", :float, ->(_params) { Arel.sql('duration') },
          description: 'Duration quantile',
          parameters: { quantile: { type: :float, description: 'Quantile to calculate' } }
        ratio :credits_per_mr,
          numerator: ->(_params) { Arel.sql('credits_used') },
          denominator: ->(_params) { Arel.sql('mr_count') },
          description: 'Credits spent per merge request'
      end
    end
  end

  let(:response_type) { described_class.build(engine_class, { types_prefix: :test }) }

  it 'declares flat metrics and dimensions as top-level fields' do
    expect(response_type.fields.keys)
      .to contain_exactly('dimensions', 'total', 'events', 'duration', 'creditsPerMrRatio')
  end

  describe 'metric parameter arguments' do
    let(:arguments) { response_type.fields['events'].arguments }

    def length_validator(argument)
      argument.validators.grep(GraphQL::Schema::Validator::LengthValidator).first
    end

    def length_error(argument, size)
      length_validator(argument).validate(nil, nil, Array.new(size, 'x'))
    end

    it 'marks a parameter declared with experiment: as experimental' do
      expect(arguments['event'].deprecation_reason).to eq('Status: Experiment. Introduced in GitLab 19.6.')
      expect(arguments['scope'].deprecation_reason).to be_nil
    end

    it 'caps array parameters at MAX_ARRAY_SIZE and states the limit in the description' do
      max_size = Types::BaseArgument::MAX_ARRAY_SIZE

      expect(length_error(arguments['event'], max_size)).to be_nil
      expect(length_error(arguments['event'], max_size + 1)).to be_present
      expect(arguments['event'].description).to start_with("Only count the given events. Up to #{max_size} values.")
    end

    it 'uses max_size: when the parameter declares one' do
      expect(length_error(arguments['label'], 5)).to be_nil
      expect(length_error(arguments['label'], 6)).to be_present
      expect(arguments['label'].description).to eq('Up to 5 values.')
    end

    it 'adds no length validation to scalar parameters' do
      expect(length_validator(arguments['scope'])).to be_nil
      expect(arguments['scope'].description).to eq('Scope to count.')
    end
  end

  it 'exposes a ratio metric as a nullable Float field' do
    field = response_type.fields['creditsPerMrRatio']

    expect(field.type).to eq(GraphQL::Types::Float)
    expect(field.description).to eq('Credits spent per merge request')
  end

  describe 'dimensions field' do
    include GraphqlHelpers

    let_it_be(:group) { create(:group) }
    let_it_be(:current_user) { create(:user) }

    let(:dimensions_type) { response_type.fields['dimensions'].type }
    let(:row) { { 'group_id_2' => group.id } }
    let(:dimensions_instance) do
      dimensions_type.allocate.tap do |instance|
        allow(instance).to receive_messages(object: row, context: { current_user: current_user })
      end
    end

    it 'exposes association dimensions as objects with their parameters as arguments' do
      expect(dimensions_type.fields.keys).to contain_exactly('userId', 'group')
      expect(dimensions_type.fields['group'].arguments.keys).to contain_exactly('depth')
    end

    it 'resolves the association from the parameterized instance key' do
      expect(batch_sync { dimensions_instance.group(depth: 2) }).to eq(group)
    end

    it 'runs the configured preloader over the loaded records for the current user' do
      expect_next_instance_of(Preloaders::GroupPolicyPreloader, [group], current_user) do |preloader|
        expect(preloader).to receive(:execute)
      end

      batch_sync { dimensions_instance.group(depth: 2) }
    end

    context 'when the dimension value is NULL' do
      let(:row) { { 'group_id_2' => nil } }

      it 'returns nil without loading the model' do
        expect(Group).not_to receive(:id_in)
        expect(batch_sync { dimensions_instance.group(depth: 2) }).to be_nil
      end
    end
  end

  describe 'metric group field' do
    let(:group_field) { response_type.fields['duration'] }
    let(:group_type) { group_field.type }

    it 'nests dotted metrics under a group field' do
      expect(group_type.graphql_name).to eq('TestAggregationResponseDurationMetrics')
      expect(group_type.fields.keys).to contain_exactly('max', 'mean', 'quantile')
    end

    it 'derives sub-field types from the metric definitions' do
      expect(group_type.fields['max'].type).to eq(GraphQL::Types::Int)
      expect(group_type.fields['mean'].type).to eq(GraphQL::Types::Float)
      expect(group_type.fields['quantile'].type).to eq(GraphQL::Types::Float)
    end

    it 'declares metric parameters as sub-field arguments' do
      expect(group_type.fields['quantile'].arguments.keys).to contain_exactly('quantile')
    end

    it 'resolves the group field to the row object itself' do
      expect(group_field.resolver_method).to eq(:object)
    end

    it 'resolves sub-field values from sanitized instance keys' do
      row = { 'duration__max' => 42, 'duration__mean' => 21.5 }
      group_instance = group_type.allocate
      allow(group_instance).to receive(:object).and_return(row)

      expect(group_instance.max).to eq(42)
      expect(group_instance.mean).to eq(21.5)
    end
  end
end
