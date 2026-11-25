# frozen_string_literal: true

require 'fast_spec_helper'
require_relative '../../../app/models/concerns/limitable'

RSpec.describe Limitable do
  let(:minimal_test_class) do
    Class.new do
      include ActiveModel::Model

      def self.name
        'TestClass'
      end

      include Limitable
    end
  end

  before do
    stub_const('MinimalTestClass', minimal_test_class)
  end

  it { expect(MinimalTestClass.limit_name).to eq('test_classes') }

  context 'with scoped limit' do
    before do
      MinimalTestClass.limit_scope = :project
    end

    it { expect(MinimalTestClass.limit_scope).to eq(:project) }

    it 'triggers scoped validations' do
      instance = MinimalTestClass.new

      expect(instance).to receive(:scoped_plan_limits)

      instance.valid?(:create)
    end

    it 'checks the limit against the custom relation' do
      MinimalTestClass.limit_relation = :custom_relation
      instance = MinimalTestClass.new
      project = Object.new
      limits = Object.new
      custom_relation = Object.new

      allow(instance).to receive_messages(project: project, custom_relation: custom_relation)
      allow(project).to receive(:actual_limits).and_return(limits)
      expect(limits).to receive(:exceeded?).with('test_classes', custom_relation).and_return(false)

      instance.valid?(:create)
    end
  end

  context 'with global limit' do
    before do
      MinimalTestClass.limit_scope = Limitable::GLOBAL_SCOPE
    end

    it { expect(MinimalTestClass.limit_scope).to eq(Limitable::GLOBAL_SCOPE) }

    it 'triggers scoped validations' do
      instance = MinimalTestClass.new

      expect(instance).to receive(:global_plan_limits)

      instance.valid?(:create)
    end
  end
end
