# frozen_string_literal: true

require 'fast_spec_helper'

RSpec.describe Gitlab::Database::Aggregation::AllowedValuesValidator, feature_category: :value_stream_management do
  describe '.allowed?' do
    using RSpec::Parameterized::TableSyntax

    where(:allowed, :value, :expected) do
      %w[a b]                                  | 'a'     | true
      %w[a b]                                  | 'c'     | false
      [/\Afoo_\d+\z/]                          | 'foo_1' | true
      [/\Afoo_\d+\z/]                          | 'foo_x' | false
      [Gitlab::UntrustedRegexp.new('\Abar\z')] | 'bar'   | true
      ['a', /\Ab\d\z/]                         | 'b1'    | true
      (0.0..1.0)                               | 0.5     | true
      (0.0..1.0)                               | 1.5     | false
    end

    with_them do
      it { expect(described_class.allowed?(allowed, value)).to eq(expected) }
    end
  end

  describe '#validate' do
    let(:record_class) do
      Struct.new(:status) do
        include ActiveModel::Validations

        def self.name
          'Record'
        end
      end
    end

    let(:options) { {} }
    let(:validator) { described_class.new(attributes: [:status], in: %w[opened merged], **options) }

    it 'adds no error when every value is allowed' do
      record = record_class.new(%w[opened merged])

      validator.validate(record)

      expect(record.errors).to be_empty
    end

    it 'adds an inclusion error to the attribute' do
      record = record_class.new(%w[merged typo])

      validator.validate(record)

      expect(record.errors.details).to eq(status: [{ error: :inclusion, values: 'typo' }])
    end

    context 'with a message' do
      let(:options) { { message: ->(_record, data) { "bad: #{data[:values]}" } } }

      it 'passes each invalid value once as values' do
        record = record_class.new(%w[merged typo typo other])

        validator.validate(record)

        expect(record.errors.map(&:message)).to contain_exactly('bad: typo, other')
      end
    end

    it 'requires in:' do
      expect { described_class.new(attributes: [:status]) }.to raise_error(ArgumentError, ':in is required')
    end
  end
end
