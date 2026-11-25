# frozen_string_literal: true

module Integrations
  module Propagation
    class BulkCreateService
      include BulkOperationHashes

      def initialize(integration, batch, association)
        @integration = integration
        @batch = batch.to_a
        @association = association
      end

      def execute
        Integration.transaction do
          inserted_records = bulk_insert_integrations

          next if inserted_records.empty?

          bulk_insert_data_fields(inserted_records) if integration.data_fields_present?

          if integration.is_a?(GitlabSlackApplication) && integration.active?
            inserted_slack_ids = bulk_insert_slack_integrations(inserted_records)
            bulk_insert_slack_integration_scopes(inserted_slack_ids)
          end
        end
      end

      private

      attr_reader :integration, :batch, :association

      def bulk_insert_integrations
        attributes = integration_hash(:create)

        items_to_insert = batch.map do |record|
          attributes.merge("#{association}_id" => record.id)
        end

        foreign_key = "#{association}_id"
        result = Integration.insert_all(
          items_to_insert,
          returning: [:id, foreign_key.to_sym]
        )

        records_by_id = batch.index_by(&:id)

        result.map { |row| [row['id'], records_by_id.fetch(row[foreign_key])] }
      end

      def bulk_insert_data_fields(inserted_records)
        model = integration.data_fields.class
        integration_fk_name = model.reflections['integration'].foreign_key
        attributes = data_fields_hash(:create)

        items_to_insert = inserted_records.map do |integration_id, record|
          attributes.merge(
            integration_fk_name => integration_id,
            "#{association}_id" => record.id
          )
        end

        bulk_insert_new(model, items_to_insert)
      end

      def bulk_insert_slack_integrations(inserted_records)
        hash = integration.slack_integration.to_database_hash

        items_to_insert = inserted_records.map do |integration_id, record|
          hash.merge(
            'integration_id' => integration_id,
            'alias' => record.full_path,
            "#{association}_id" => record.id
          )
        end

        bulk_insert_new(SlackIntegration, items_to_insert)
      end

      def bulk_insert_slack_integration_scopes(inserted_slack_ids)
        scopes = integration.slack_integration.slack_api_scopes

        items_to_insert = SlackIntegration.id_in(inserted_slack_ids).flat_map do |slack_integration|
          scopes.map do |scope|
            {
              'slack_integration_id' => slack_integration.id,
              'slack_api_scope_id' => scope.id,
              'project_id' => slack_integration.project_id,
              'group_id' => slack_integration.group_id,
              'organization_id' => slack_integration.organization_id
            }
          end
        end

        bulk_insert_new(SlackWorkspace::IntegrationApiScope, items_to_insert)
      end
    end
  end
end
