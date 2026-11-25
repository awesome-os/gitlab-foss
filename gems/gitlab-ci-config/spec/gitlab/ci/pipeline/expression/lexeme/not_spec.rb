# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Ci::Pipeline::Expression::Lexeme::Not do
  let(:operand) { instance_double(Gitlab::Ci::Pipeline::Expression::Lexeme::Variable, evaluate: nil) }

  describe '.build' do
    it 'creates a new instance of the token' do
      expect(described_class.build('!', operand)).to be_a(described_class)
    end

    context 'with a non-evaluable operand' do
      let(:operand) { Object.new }

      it 'raises an operator error' do
        expect { described_class.build('!', operand) }.to raise_error Gitlab::Ci::Pipeline::Expression::Lexeme::Operator::OperatorError
      end
    end
  end

  describe '.type' do
    it 'is a unary operator' do
      expect(described_class.type).to eq :unary_operator
    end
  end

  describe '.precedence' do
    it 'binds tighter than the logical operators' do
      expect(described_class.precedence).to be < Gitlab::Ci::Pipeline::Expression::Lexeme::And.precedence
    end
  end

  describe '#inspect' do
    it 'wraps the operand' do
      allow(operand).to receive(:inspect).and_return('$VAR')

      expect(described_class.new(operand).inspect).to eq 'not($VAR)'
    end
  end

  describe '#evaluate' do
    let(:variables) { { 'VAR' => 'value' } }

    subject { described_class.new(operand).evaluate(variables) }

    before do
      allow(operand).to receive(:evaluate).with(variables).and_return(operand_value)
    end

    context 'when the operand is present' do
      where(:operand_value) { [true, 1, 'a', ['a'], { a: 1 }] }

      with_them do
        it { is_expected.to be false }
      end
    end

    context 'when the operand is blank' do
      where(:operand_value) { [false, nil, '', ' ', [], {}] }

      with_them do
        it { is_expected.to be true }
      end
    end
  end
end
