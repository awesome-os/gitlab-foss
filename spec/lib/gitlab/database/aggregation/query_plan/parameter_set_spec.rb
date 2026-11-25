# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Database::Aggregation::QueryPlan::ParameterSet, feature_category: :value_stream_management do
  let(:definition_class) do
    Class.new(Gitlab::Database::Aggregation::PartDefinition) do
      include Gitlab::Database::Aggregation::ParameterizedDefinition
    end
  end

  let(:specs) { { status: { type: :string } } }
  let(:definition) { definition_class.new(:foo, :string, nil, parameters: specs) }

  def build_set(values)
    described_class.new(definition, { parameters: values })
  end

  describe '#[]' do
    it 'returns the request value' do
      expect(build_set({ status: 'success' })[:status]).to eq('success')
    end

    it 'keeps a false value' do
      expect(build_set({ status: false })[:status]).to be(false)
    end

    it 'returns nil for an undeclared parameter' do
      expect(build_set({ other: 'x' })[:other]).to be_nil
    end

    context 'with array: true' do
      let(:specs) { { status: { type: :string, array: true } } }

      it 'wraps a scalar value' do
        expect(build_set({ status: 'success' })[:status]).to eq(['success'])
      end
    end

    context 'with a formatter' do
      let(:formatter) { instance_double(Proc) }
      let(:specs) { { status: { type: :string, array: true, formatter: formatter } } }

      it 'returns the formatted value and runs the formatter once' do
        expect(formatter).to receive(:call).with(%w[a b]).once.and_return([1, 2])

        set = build_set({ status: %w[a b] })

        expect(set[:status]).to eq([1, 2])
        expect(set[:status]).to eq([1, 2])
      end

      it 'does not call the formatter when the parameter is missing' do
        expect(formatter).not_to receive(:call)

        expect(build_set({})[:status]).to be_nil
      end
    end
  end

  context 'with a definition that has no parameters' do
    let(:definition) { Gitlab::Database::Aggregation::PartDefinition.new(:foo, :string) }

    it 'is valid and has no values' do
      set = build_set({ status: 'a' })

      expect(set).to be_valid
      expect(set[:status]).to be_nil
      expect(set.expression_params).to eq({})
    end
  end

  describe '#expression_params' do
    let(:specs) do
      { status: { type: :string, array: true, formatter: ->(v) { v.map(&:upcase) } }, depth: { type: :integer } }
    end

    it 'returns the raw values of the given parameters only' do
      expect(build_set({ status: 'a', other: 1 }).expression_params).to eq(status: ['a'])
    end
  end

  describe 'validation' do
    context 'with in:' do
      using RSpec::Parameterized::TableSyntax

      where(:allowed, :value, :valid) do
        %w[success failed]                        | 'success' | true
        %w[success failed]                        | 'bogus'   | false
        ['monthly', /\A\d+d\z/]                   | '30d'     | true
        ['monthly', /\A\d+d\z/]                   | '30days'  | false
        [Gitlab::UntrustedRegexp.new('\A\d+d\z')] | '30d'     | true
        (0.0..1.0)                                | 0.5       | true
        (0.0..1.0)                                | 1.5       | false
      end

      with_them do
        let(:specs) { { status: { type: :string, in: allowed } } }

        it { expect(build_set({ status: value }).valid?).to eq(valid) }
      end

      it 'is valid when the parameter is not given' do
        expect(build_set({})).to be_valid
      end
    end

    context 'with an array: true parameter constrained by in:' do
      let(:specs) { { status: { type: :string, in: %w[success failed], array: true } } }

      it 'lists each invalid element once' do
        set = build_set({ status: %w[success bogus bogus other] })

        expect(set).not_to be_valid
        expect(set.errors.map(&:message))
          .to contain_exactly('Invalid values for parameter `status` of `foo`: bogus, other')
      end
    end

    it 'keeps interpolation placeholders in rejected values as plain text' do
      specs[:status][:in] = %w[success]

      set = build_set({ status: '%{x} %<y>s 100%' })

      expect(set).not_to be_valid
      expect(set.errors.map(&:message))
        .to contain_exactly('Invalid values for parameter `status` of `foo`: %{x} %<y>s 100%')
    end

    it 'checks the raw values, not the formatted ones' do
      specs[:status].merge!(in: %w[a], formatter: ->(values) { Array.wrap(values) & %w[a] })

      expect(build_set({ status: 'typo' })).not_to be_valid
    end

    context 'with max_size:' do
      let(:specs) { { status: { type: :string, array: true, max_size: 2 } } }

      it 'is valid at the limit' do
        expect(build_set({ status: %w[a b] })).to be_valid
      end

      it 'adds an error over the limit' do
        set = build_set({ status: %w[a b c] })

        expect(set).not_to be_valid
        expect(set.errors.map(&:message)).to contain_exactly("Parameter `status` of `foo` can't be longer than 2")
      end

      it 'puts the error on the parameter key' do
        set = build_set({ status: %w[a b c] })

        set.validate

        expect(set.errors.attribute_names).to eq([:status])
      end

      it 'limits the length of a String value' do
        specs[:status] = { type: :string, max_size: 3 }

        set = build_set({ status: 'abcd' })

        expect(build_set({ status: 'abc' })).to be_valid
        expect(set).not_to be_valid
        expect(set.errors.map(&:message)).to contain_exactly("Parameter `status` of `foo` can't be longer than 3")
      end
    end

    context 'with required:' do
      let(:specs) { { status: { type: :string, array: true, required: true } } }

      it 'adds an error when the parameter is missing or empty' do
        [{}, { status: [] }].each do |values|
          set = build_set(values)

          expect(set).not_to be_valid
          expect(set.errors.map(&:message)).to contain_exactly('Parameter `status` of `foo` is required')
        end
      end

      it 'treats a blank single value as missing' do
        specs[:status] = { type: :string, required: true }

        expect(build_set({ status: '' })).not_to be_valid
        expect(build_set({ status: 'a' })).to be_valid
      end
    end

    context 'with an array: true parameter' do
      let(:specs) { { status: { type: :string, array: true } } }

      it 'adds an error for an empty list' do
        set = build_set({ status: [] })

        expect(set).not_to be_valid
        expect(set.errors.map(&:message)).to contain_exactly('Parameter `status` of `foo` is required')
      end

      it 'is valid when the parameter is not given or nil' do
        expect(build_set({})).to be_valid
        expect(build_set({ status: nil })).to be_valid
      end

      it 'drops duplicate values' do
        set = build_set({ status: %w[a a b b c] })

        expect(set).to be_valid
        expect(set[:status]).to eq(%w[a b c])
        expect(set.expression_params).to eq(status: %w[a b c])
      end
    end

    context 'without array: true' do
      it 'does not reject an empty list' do
        expect(build_set({ status: [] })).to be_valid
      end
    end

    context 'with combination rules' do
      let(:specs) { { status: { type: :string, in: %w[a b] } } }

      before do
        allow(definition).to receive(:validate_parameters) do |set|
          set.errors.add(:base, 'combination error')
        end
      end

      it 'runs them when every spec rule passes' do
        set = build_set({ status: 'a' })

        expect(set).not_to be_valid
        expect(set.errors.map(&:message)).to contain_exactly('combination error')
      end

      it 'skips them when a spec rule fails' do
        set = build_set({ status: 'c' })

        expect(set).not_to be_valid
        expect(definition).not_to have_received(:validate_parameters)
      end
    end
  end
end
