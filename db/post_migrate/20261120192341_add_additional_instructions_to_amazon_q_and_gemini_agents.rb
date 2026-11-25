# frozen_string_literal: true

class AddAdditionalInstructionsToAmazonQAndGeminiAgents < Gitlab::Database::Migration[2.4]
  milestone '19.7'

  restrict_gitlab_migration gitlab_schema: :gitlab_main_org

  ITEM_IDS = [2331, 2332].freeze
  THIRD_PARTY_FLOW_TYPE = 3
  VARIABLE = 'ADDITIONAL_INSTRUCTIONS'
  REFERENCE = '$ADDITIONAL_INSTRUCTIONS'

  class AiCatalogItem < MigrationRecord
    self.table_name = 'ai_catalog_items'
  end

  class AiCatalogItemVersion < MigrationRecord
    self.table_name = 'ai_catalog_item_versions'
  end

  def up
    return unless Gitlab.com_except_jh?

    item_ids = AiCatalogItem.where(id: ITEM_IDS, item_type: THIRD_PARTY_FLOW_TYPE).select(:id)

    AiCatalogItemVersion.where(ai_catalog_item_id: item_ids).find_each { |version| add_variable(version) }
  end

  def down
    # no-op: can't tell the rows changed by `up` from versions that declared the variable themselves
  end

  private

  def add_variable(version)
    definition = version.definition
    yaml = definition['yaml_definition']
    variables = definition['variables']

    return unless yaml.is_a?(String) && variables.is_a?(Array)
    return unless yaml.include?(REFERENCE)
    return if variables.include?(VARIABLE)

    new_yaml = yaml_with_variable(yaml)
    return unless new_yaml

    version.update_columns(
      definition: definition.merge('variables' => variables + [VARIABLE], 'yaml_definition' => new_yaml),
      updated_at: Time.current
    )
  end

  def yaml_with_variable(yaml)
    candidate = yaml.end_with?("\n") ? "#{yaml}  - #{VARIABLE}\n" : "#{yaml}\n  - #{VARIABLE}"
    before = YAML.safe_load(yaml, permitted_classes: [], aliases: false)
    after = YAML.safe_load(candidate, permitted_classes: [], aliases: false)

    return unless before.is_a?(Hash) && after.is_a?(Hash)
    return unless after['variables'] == Array(before['variables']) + [VARIABLE]
    return unless after.except('variables') == before.except('variables')

    candidate
  rescue Psych::Exception
    nil
  end
end
