# frozen_string_literal: true

require 'spec_helper'
require_migration!

RSpec.describe AddAdditionalInstructionsToAmazonQAndGeminiAgents,
  migration: :gitlab_main_org,
  feature_category: :workflow_catalog do
  using RSpec::Parameterized::TableSyntax

  let(:organizations) { table(:organizations) }
  let(:ai_catalog_items) { table(:ai_catalog_items) }
  let(:ai_catalog_item_versions) { table(:ai_catalog_item_versions) }

  let(:organization) { organizations.create!(name: 'Organization', path: 'organization') }

  let(:third_party_flow_type) { 3 }
  let(:flow_type) { 2 }

  let(:variable) { 'ADDITIONAL_INSTRUCTIONS' }
  let(:gemini_variables) { %w[GOOGLE_CREDENTIALS GOOGLE_CLOUD_PROJECT GOOGLE_CLOUD_LOCATION] }
  let(:amazon_q_variables) { %w[AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_REGION_NAME AMAZON_Q_SIGV4] }

  let(:gemini_definition) { definition_for(yaml_for(gemini_variables)) }
  let(:amazon_q_definition) { definition_for(yaml_for(amazon_q_variables)) }
  let(:updated_gemini_definition) { definition_for(yaml_for(gemini_variables + [variable])) }
  let(:updated_amazon_q_definition) { definition_for(yaml_for(amazon_q_variables + [variable])) }

  let(:gemini_item) { create_item(name: 'Develop with Gemini') }
  let(:amazon_q_item) { create_item(name: 'Amazon Q Developer') }

  let!(:gemini_version) { create_version(gemini_item, gemini_definition) }
  let!(:amazon_q_version) { create_version(amazon_q_item, amazon_q_definition) }
  let!(:older_amazon_q_version) { create_version(amazon_q_item, amazon_q_definition, version: '0.9.0') }

  before do
    stub_const("#{described_class}::ITEM_IDS", [gemini_item.id, amazon_q_item.id])
    allow(Gitlab).to receive(:com_except_jh?).and_return(true)
  end

  def yaml_for(variables, prompt: '$AI_FLOW_INPUT $ADDITIONAL_INSTRUCTIONS')
    <<~YAML.chomp
      image: node:22-slim
      commands:
        - npm install --global agent-cli
        - agent --prompt "#{prompt}"
      variables:
      #{variables.map { |name| "  - #{name}" }.join("\n")}
    YAML
  end

  def definition_for(yaml)
    YAML.safe_load(yaml, permitted_classes: [], aliases: false).merge('yaml_definition' => yaml)
  end

  def definition_of(version)
    ai_catalog_item_versions.find(version.id).definition
  end

  def create_item(name:, item_type: third_party_flow_type)
    ai_catalog_items.create!(
      name: name,
      description: 'An external agent',
      organization_id: organization.id,
      item_type: item_type,
      verification_level: 100
    )
  end

  def create_version(item, definition, version: '1.0.0')
    ai_catalog_item_versions.create!(
      ai_catalog_item_id: item.id,
      version: version,
      organization_id: organization.id,
      schema_version: 1,
      release_date: Time.current,
      definition: definition
    )
  end

  describe '#up' do
    it 'adds the variable to every version of both agents, leaving the rest intact', :aggregate_failures do
      migrate!

      expect(definition_of(gemini_version)).to eq(updated_gemini_definition)
      expect(definition_of(amazon_q_version)).to eq(updated_amazon_q_definition)
      expect(definition_of(older_amazon_q_version)).to eq(updated_amazon_q_definition)
    end

    context 'when the YAML ends with a newline' do
      let(:gemini_definition) { definition_for("#{yaml_for(gemini_variables)}\n") }

      it 'adds the variable and keeps the trailing newline' do
        migrate!

        expect(definition_of(gemini_version))
          .to eq(definition_for("#{yaml_for(gemini_variables + [variable])}\n"))
      end
    end

    context 'when a version cannot be updated' do
      let(:unused_variable) { definition_for(yaml_for(gemini_variables, prompt: '$AI_FLOW_INPUT')) }
      let(:missing_yaml) { definition_for(yaml_for(gemini_variables)).except('yaml_definition') }
      let(:missing_variables) { definition_for(yaml_for(gemini_variables)).except('variables') }

      let(:variables_not_last) do
        definition_for(<<~YAML.chomp)
          image: node:22-slim
          variables:
            - GOOGLE_CREDENTIALS
          commands:
            - agent --prompt "$AI_FLOW_INPUT $ADDITIONAL_INSTRUCTIONS"
        YAML
      end

      let(:inline_variables) do
        definition_for(<<~YAML.chomp)
          image: node:22-slim
          commands:
            - agent --prompt "$AI_FLOW_INPUT $ADDITIONAL_INSTRUCTIONS"
          variables: [GOOGLE_CREDENTIALS]
        YAML
      end

      let(:yaml_not_a_mapping) do
        definition_for(yaml_for(gemini_variables)).merge('yaml_definition' => '- $ADDITIONAL_INSTRUCTIONS')
      end

      where(:case_name, :gemini_definition) do
        'the variable is not used'            | ref(:unused_variable)
        'the variable is already declared'    | ref(:updated_gemini_definition)
        'yaml_definition is missing'          | ref(:missing_yaml)
        'variables is missing'                | ref(:missing_variables)
        'variables is not the last YAML key'  | ref(:variables_not_last)
        'variables is an inline YAML list'    | ref(:inline_variables)
        'the YAML is not a mapping'           | ref(:yaml_not_a_mapping)
      end

      with_them do
        it 'leaves the version unchanged and still updates the other agent', :aggregate_failures do
          migrate!

          expect(definition_of(gemini_version)).to eq(gemini_definition)
          expect(definition_of(amazon_q_version)).to eq(updated_amazon_q_definition)
        end
      end
    end

    context 'with another external agent that uses the variable' do
      let!(:other_version) { create_version(create_item(name: 'Other Agent'), gemini_definition) }

      it 'leaves it unchanged' do
        migrate!

        expect(definition_of(other_version)).to eq(gemini_definition)
      end
    end

    context 'when the item is not an external agent' do
      let(:gemini_item) { create_item(name: 'Develop with Gemini', item_type: flow_type) }

      it 'leaves it unchanged' do
        migrate!

        expect(definition_of(gemini_version)).to eq(gemini_definition)
      end
    end

    context 'when not on GitLab.com' do
      before do
        allow(Gitlab).to receive(:com_except_jh?).and_return(false)
      end

      it 'does not update any version', :aggregate_failures do
        migrate!

        expect(definition_of(gemini_version)).to eq(gemini_definition)
        expect(definition_of(amazon_q_version)).to eq(amazon_q_definition)
      end
    end
  end

  describe '#down' do
    it 'keeps the variable', :aggregate_failures do
      migrate!
      schema_migrate_down!

      expect(definition_of(gemini_version)).to eq(updated_gemini_definition)
      expect(definition_of(amazon_q_version)).to eq(updated_amazon_q_definition)
    end
  end
end
