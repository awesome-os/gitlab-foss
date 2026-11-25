# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Encryption::DbKeyBaseRotation::Registry, :eager_load, feature_category: :cell do
  # Checked in so that a new encrypted column can not be missed silently: add it here, and check
  # that re-encrypting its rows is safe.
  let(:ce_tables) do
    {
      alert_management_http_integrations: %w[encrypted_token],
      application_settings: %w[
        encrypted_akismet_api_key
        encrypted_arkose_labs_client_secret
        encrypted_arkose_labs_client_xid
        encrypted_arkose_labs_data_exchange_key
        encrypted_arkose_labs_private_api_key
        encrypted_arkose_labs_public_api_key
        encrypted_asset_proxy_secret_key
        encrypted_ci_job_token_signing_key
        encrypted_ci_jwt_signing_key
        encrypted_cloud_license_auth_token
        encrypted_cube_api_key
        encrypted_customers_dot_jwt_signing_key
        encrypted_database_grafana_api_key
        encrypted_eks_secret_access_key
        encrypted_elasticsearch_aws_secret_access_key
        encrypted_elasticsearch_password
        encrypted_external_auth_client_key
        encrypted_external_auth_client_key_pass
        encrypted_external_pipeline_validation_service_token
        encrypted_lets_encrypt_private_key
        encrypted_mailgun_signing_key
        encrypted_product_analytics_configurator_connection_string
        encrypted_recaptcha_private_key
        encrypted_recaptcha_site_key
        encrypted_secret_detection_service_auth_token
        encrypted_secret_detection_token_revocation_token
        encrypted_slack_app_secret
        encrypted_slack_app_signing_secret
        encrypted_slack_app_verification_token
        encrypted_spam_check_api_key
        encrypted_telesign_api_key
        encrypted_telesign_customer_xid
        error_tracking_access_token_encrypted
        runners_registration_token_encrypted
        static_objects_external_storage_auth_token_encrypted
      ],
      atlassian_identities: %w[encrypted_refresh_token encrypted_token],
      bulk_import_configurations: %w[encrypted_access_token encrypted_url],
      chat_names: %w[encrypted_token],
      ci_group_variables: %w[encrypted_value],
      ci_instance_variables: %w[encrypted_value],
      ci_job_variables: %w[encrypted_value],
      ci_pipeline_schedule_variables: %w[encrypted_value],
      ci_runners: %w[token_encrypted],
      ci_triggers: %w[token_encrypted],
      ci_variables: %w[encrypted_value],
      cluster_agent_tokens: %w[token_encrypted],
      cluster_platforms_kubernetes: %w[encrypted_password encrypted_token],
      cluster_providers_aws: %w[encrypted_secret_access_key],
      cluster_providers_gcp: %w[encrypted_access_token],
      clusters_kubernetes_namespaces: %w[encrypted_service_account_token],
      deploy_tokens: %w[token_encrypted],
      integrations: %w[encrypted_properties],
      issue_tracker_data: %w[encrypted_issues_url encrypted_new_issue_url encrypted_project_url],
      jira_connect_installations: %w[encrypted_forge_system_token encrypted_shared_secret],
      jira_tracker_data: %w[encrypted_api_url encrypted_password encrypted_url encrypted_username],
      namespaces: %w[runners_token_encrypted],
      operations_feature_flags_clients: %w[token_encrypted],
      p_ci_builds: %w[token_encrypted],
      p_ci_pipeline_variables: %w[encrypted_value],
      packages_debian_group_distribution_keys: %w[encrypted_passphrase encrypted_private_key],
      packages_debian_project_distribution_keys: %w[encrypted_passphrase encrypted_private_key],
      pages_domain_acme_orders: %w[encrypted_private_key],
      pages_domains: %w[encrypted_key],
      project_error_tracking_settings: %w[encrypted_token],
      project_import_data: %w[encrypted_credentials],
      project_incident_management_settings: %w[encrypted_pagerduty_token],
      project_settings: %w[encrypted_cube_api_key encrypted_product_analytics_configurator_connection_string],
      projects: %w[runners_token_encrypted],
      remote_mirrors: %w[encrypted_credentials],
      service_access_tokens: %w[encrypted_token],
      service_desk_custom_email_credentials: %w[encrypted_smtp_password encrypted_smtp_username],
      service_desk_custom_email_verifications: %w[encrypted_token],
      slack_integrations: %w[encrypted_bot_access_token],
      snippets: %w[encrypted_secret_token],
      users: %w[static_object_token_encrypted],
      web_hooks: %w[encrypted_custom_headers encrypted_token encrypted_url encrypted_url_variables],
      zentao_tracker_data: %w[encrypted_api_token encrypted_api_url encrypted_url encrypted_zentao_product_xid]
    }
  end

  let(:ee_tables) do
    {
      ai_self_hosted_models: %w[encrypted_api_token],
      audit_events_amazon_s3_configurations: %w[encrypted_secret_access_key],
      audit_events_google_cloud_logging_configurations: %w[encrypted_private_key],
      audit_events_group_external_streaming_destinations: %w[encrypted_secret_token],
      audit_events_instance_amazon_s3_configurations: %w[encrypted_secret_access_key],
      audit_events_instance_external_audit_event_destinations: %w[encrypted_verification_token],
      audit_events_instance_external_streaming_destinations: %w[encrypted_secret_token],
      audit_events_instance_google_cloud_logging_configurations: %w[encrypted_private_key],
      cluster_agent_url_configurations: %w[encrypted_private_key],
      compliance_requirements_controls: %w[encrypted_secret_token],
      dast_site_profile_secret_variables: %w[encrypted_value],
      dependency_proxy_packages_settings: %w[
        encrypted_maven_external_registry_password
        encrypted_maven_external_registry_username
        encrypted_npm_external_registry_auth_token
        encrypted_npm_external_registry_basic_auth
      ],
      external_status_checks: %w[encrypted_shared_secret],
      geo_nodes: %w[encrypted_secret_access_key],
      group_scim_auth_access_tokens: %w[token_encrypted],
      scim_oauth_access_tokens: %w[token_encrypted],
      status_page_settings: %w[encrypted_aws_secret_key],
      system_access_group_microsoft_applications: %w[encrypted_client_secret],
      system_access_group_microsoft_graph_access_tokens: %w[encrypted_token],
      system_access_microsoft_applications: %w[encrypted_client_secret],
      system_access_microsoft_graph_access_tokens: %w[encrypted_token],
      workspace_tokens: %w[token_encrypted],
      workspace_variables: %w[encrypted_value]
    }
  end

  let(:text_cbc_columns) do
    %w[
      application_settings.encrypted_asset_proxy_secret_key
      ci_group_variables.encrypted_value
      ci_pipeline_schedule_variables.encrypted_value
      ci_variables.encrypted_value
      cluster_platforms_kubernetes.encrypted_password
      cluster_platforms_kubernetes.encrypted_token
      cluster_providers_gcp.encrypted_access_token
      clusters_kubernetes_namespaces.encrypted_service_account_token
      external_status_checks.encrypted_shared_secret
      p_ci_pipeline_variables.encrypted_value
      pages_domains.encrypted_key
      snippets.encrypted_secret_token
    ]
  end

  describe '.tables' do
    subject(:tables) { described_class.tables }

    def db_key_base_columns
      ActiveRecord::Base.descendants.flat_map do |model| # rubocop:disable Database/MultipleDatabases -- also catches models outside ApplicationRecord, which the registry skips
        next [] if model.abstract_class? || model.name.nil?
        next [] if model.name.match?(described_class::BACKGROUND_MIGRATION_MODEL)

        attributes = Array(model.try(:attr_encrypted_encrypted_attributes)).filter_map do |_attribute, options|
          options[:attribute].to_s if Gitlab::EncryptedAttribute::DB_KEY_BASE_KEY_TYPES.include?(options[:key])
        end
        tokens = Array(model.try(:encrypted_token_authenticatable_fields)).map { |field| "#{field}_encrypted" }

        (attributes + tokens).map { |column| "#{model.table_name}.#{column}" }
      end.uniq
    end

    def columns_by_table
      tables.to_h { |table| [table.name.to_sym, table.encrypted_columns.map { |column| column.columns.first }.sort] }
    end

    it 'matches the checked-in list', unless: Gitlab.ee? do
      expect(columns_by_table).to eq(ce_tables)
    end

    it 'matches the checked-in list', if: Gitlab.ee? do
      expect(columns_by_table).to eq(ce_tables.merge(ee_tables) { |_table, ce, ee| (ce + ee).sort })
    end

    it 'includes every attribute and token field encrypted with a db_key_base key' do
      registered = tables.flat_map do |table|
        table.encrypted_columns.map { |column| "#{table.name}.#{column.columns.first}" }
      end

      expect(db_key_base_columns - registered).to be_empty,
        'Add these columns to the registry, or exclude them there with the reason they are safe to skip'
    end

    # Plausibility breaks ties between CBC keys with a valid UTF-8 check, which can pick a wrong key
    # for a binary value. Check that a new column holds text before adding it here.
    it 'only has text in the CBC columns that are not marshaled' do
      cbc_columns = tables.flat_map do |table|
        table.encrypted_columns
          .select { |column| column.is_a?(Gitlab::Encryption::DbKeyBaseRotation::AttrEncryptedColumn) }
          .select { |column| column.definition[:algorithm].end_with?('-cbc') && !column.definition[:marshal] }
          .map { |column| "#{table.name}.#{column.columns.first}" }
      end

      expect(cbc_columns - text_cbc_columns).to be_empty
    end

    it 'does not load the application again when it is eager loaded' do
      allow(Rails.application.config).to receive(:eager_load).and_return(true)

      expect(Rails.application).not_to receive(:eager_load!)

      tables
    end

    it 'orders the tables by name' do
      expect(tables.map(&:name)).to eq(tables.map(&:name).sort)
    end

    it 'skips the EE background migration copies of models', if: Gitlab.ee? do
      copy = EE::Gitlab::BackgroundMigration::CreateMissingExternalLinksForVulnerabilities::JiraTrackerData
      models = ApplicationRecord.descendants
      allow(ApplicationRecord).to receive(:descendants).and_return([copy, *(models - [copy])])

      expect(tables.find { |table| table.name == 'jira_tracker_data' }.model).to eq(Integrations::JiraTrackerData)
    end

    it 'queries STI tables with their base class' do
      expect(tables.find { |table| table.name == 'p_ci_builds' }.model).to eq(CommitStatus)
    end
  end

  describe '#tables' do
    it 'raises when two models encrypt the same column differently' do
      registry = described_class.new
      allow(registry).to receive(:models).and_return([ProjectHook, SystemHook])
      allow(Gitlab::Encryption::DbKeyBaseRotation::AttrEncryptedColumn)
        .to receive(:new).and_wrap_original do |method, model, attribute|
          method.call(model, attribute).tap do |column|
            allow(column).to receive(:definition).and_return(model: model.name)
          end
        end

      expect { registry.tables }.to raise_error(described_class::DefinitionMismatchError, /SystemHook/)
    end
  end
end
