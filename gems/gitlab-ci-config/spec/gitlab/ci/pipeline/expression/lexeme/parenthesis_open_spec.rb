# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Ci::Pipeline::Expression::Lexeme::ParenthesisOpen do
  describe '.type' do
    it { expect(described_class.type).to eq :parenthesis_open }
  end

  describe '.precedence' do
    it 'is higher than every other operator' do
      operators = Gitlab::Ci::Pipeline::Expression::Lexer.lexemes.select do |lexeme|
        lexeme < Gitlab::Ci::Pipeline::Expression::Lexeme::Operator
      end
      others = operators - [described_class]

      expect(others.map(&:precedence)).to all(be < described_class.precedence)
    end
  end

  describe '.scan' do
    it 'matches an opening parenthesis' do
      expect(described_class.scan(StringScanner.new('($VAR)')).value).to eq '('
    end

    it 'does not match a closing parenthesis' do
      expect(described_class.scan(StringScanner.new(')'))).to be_nil
    end
  end
end
