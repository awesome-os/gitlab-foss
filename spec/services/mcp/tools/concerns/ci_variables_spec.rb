# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mcp::Tools::Concerns::CiVariables, feature_category: :mcp_server do
  let(:test_tool_class) do
    Class.new do
      include Mcp::Tools::Concerns::CiVariables

      attr_reader :params

      def initialize(params)
        @params = params
      end
    end
  end

  let(:params) { {} }
  let(:tool) { test_tool_class.new(params) }

  describe '#ci_variables' do
    subject(:variables) { tool.send(:ci_variables) }

    it 'omits variables when none are provided' do
      expect(variables).to be_nil
    end

    context 'with an empty list' do
      let(:params) { { variables: [] } }

      it 'omits the mutation input' do
        expect(variables).to be_nil
      end
    end

    context 'with string and symbol keys' do
      let(:params) do
        {
          variables: [
            { 'key' => 'DEPLOY_ENV', 'value' => 'staging', 'variable_type' => 'env_var' },
            { key: 'CONFIG', value: 'configuration', variable_type: 'file' },
            { key: 'DEFAULT_TYPE', value: 'default' }
          ]
        }
      end

      it 'maps enum names and preserves an omitted variable type' do
        expect(variables).to eq([
          { key: 'DEPLOY_ENV', value: 'staging', variableType: 'ENV_VAR' },
          { key: 'CONFIG', value: 'configuration', variableType: 'FILE' },
          { key: 'DEFAULT_TYPE', value: 'default' }
        ])
      end
    end
  end
end
