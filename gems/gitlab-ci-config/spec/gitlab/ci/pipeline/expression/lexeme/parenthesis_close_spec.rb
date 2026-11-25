# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Ci::Pipeline::Expression::Lexeme::ParenthesisClose do
  describe '.type' do
    it { expect(described_class.type).to eq :parenthesis_close }
  end

  describe '.precedence' do
    it 'is higher than every operator but the opening parenthesis' do
      operators = Gitlab::Ci::Pipeline::Expression::Lexer.lexemes.select do |lexeme|
        lexeme < Gitlab::Ci::Pipeline::Expression::Lexeme::Operator
      end
      others = operators - [described_class, Gitlab::Ci::Pipeline::Expression::Lexeme::ParenthesisOpen]

      expect(others.map(&:precedence)).to all(be < described_class.precedence)
    end

    it 'is lower than the opening parenthesis' do
      expect(described_class.precedence).to be < Gitlab::Ci::Pipeline::Expression::Lexeme::ParenthesisOpen.precedence
    end
  end

  describe '.scan' do
    it 'matches a closing parenthesis' do
      expect(described_class.scan(StringScanner.new(')')).value).to eq ')'
    end

    it 'does not match an opening parenthesis' do
      expect(described_class.scan(StringScanner.new('('))).to be_nil
    end
  end
end
