# frozen_string_literal: true

module API
  module Entities
    class ApplicationSetting < Grape::Entity
      STRING_LIST = { type: 'String', is_array: true }.freeze
      INTEGER_LIST = { type: 'Integer', is_array: true }.freeze
      OBJECT_LIST = { type: 'Hash', is_array: true }.freeze
      OBJECT = { type: 'Hash' }.freeze

      # Documentation for exposed attributes whose values are not strings.
      ATTRIBUTE_DOCUMENTATION = {
        allowed_integrations: STRING_LIST,
        asset_proxy_allowlist: STRING_LIST,
        ci_cd_catalog_projects_allowlist: STRING_LIST,
        code_dropdown_custom_clients: OBJECT_LIST,
        disabled_oauth_sign_in_sources: STRING_LIST,
        domain_allowlist: STRING_LIST,
        domain_denylist: STRING_LIST,
        elasticsearch_namespace_ids: INTEGER_LIST,
        elasticsearch_project_ids: INTEGER_LIST,
        elasticsearch_url: STRING_LIST,
        foundational_agents_statuses: OBJECT_LIST,
        git_rate_limit_users_alertlist: INTEGER_LIST,
        git_rate_limit_users_allowlist: STRING_LIST,
        iframe_rendering_allowlist: STRING_LIST,
        import_sources: STRING_LIST,
        jira_connect_domain_allowlist: STRING_LIST,
        outbound_local_requests_whitelist: STRING_LIST,
        package_metadata_purl_types: INTEGER_LIST,
        default_branch_protection_defaults: OBJECT,
        dependency_management_settings: OBJECT,
        kroki_formats: OBJECT,
        resource_usage_limits: OBJECT,
        sign_in_restrictions: OBJECT,
        vscode_extension_marketplace: OBJECT
      }.freeze

      def self.exposed_attributes
        attributes = ::ApplicationSettingsHelper.visible_attributes
        attributes.delete(:performance_bar_allowed_group_path)
        attributes.delete(:performance_bar_enabled)
        attributes.delete(:allow_local_requests_from_hooks_and_services)
        attributes.delete(:repository_storages_weighted)

        # let's not expose the secret key in a response
        attributes.delete(:asset_proxy_secret_key)
        attributes.delete(:eks_secret_access_key)
        attributes.delete(:o11y_provisioner_api_key)

        attributes
      end

      expose :id, :performance_bar_allowed_group_id
      exposed_attributes.each { |attribute| expose attribute, documentation: ATTRIBUTE_DOCUMENTATION[attribute] }
      expose(:restricted_visibility_levels, documentation: STRING_LIST) do |setting, _options|
        setting.restricted_visibility_levels.map { |level| Gitlab::VisibilityLevel.string_level(level) }
      end
      expose(:default_project_visibility) { |setting, _options| Gitlab::VisibilityLevel.string_level(setting.default_project_visibility) }
      expose(:default_snippet_visibility) { |setting, _options| Gitlab::VisibilityLevel.string_level(setting.default_snippet_visibility) }
      expose(:default_group_visibility) { |setting, _options| Gitlab::VisibilityLevel.string_level(setting.default_group_visibility) }
      expose(:valid_runner_registrars, documentation: STRING_LIST) { |setting, _options| setting.valid_runner_registrars }

      expose(*::ApplicationSettingsHelper.external_authorization_service_attributes)

      # Also expose these columns under their new attribute names.
      #
      # TODO: Once we rename the columns, we have to swap this around and keep supporting the old names until v5.
      # https://gitlab.com/gitlab-org/gitlab/-/issues/340031
      expose :throttle_unauthenticated_enabled, as: :throttle_unauthenticated_web_enabled
      expose :throttle_unauthenticated_period_in_seconds, as: :throttle_unauthenticated_web_period_in_seconds
      expose :throttle_unauthenticated_requests_per_period, as: :throttle_unauthenticated_web_requests_per_period

      # support legacy names, can be removed in v5
      expose :password_authentication_enabled_for_web, as: :password_authentication_enabled
      expose :password_authentication_enabled_for_web, as: :signin_enabled
      expose :allow_local_requests_from_web_hooks_and_services, as: :allow_local_requests_from_hooks_and_services
      expose :asset_proxy_allowlist, as: :asset_proxy_whitelist, documentation: STRING_LIST
      expose :iframe_rendering_enabled
      expose :iframe_rendering_allowlist, documentation: STRING_LIST
      expose :iframe_rendering_allowlist_raw
      expose :email_otp_enabled

      expose :ci_job_trace_update_interval, documentation: { type: Integer }
      expose :ci_job_trace_update_interval_when_being_watched, documentation: { type: Integer }
      expose :logging_field_schema_version, documentation: { type: Integer }
      expose :logging_field_dual_emit_target, documentation: { type: Integer }

      # This field is deprecated and always returns true
      expose(:housekeeping_bitmaps_enabled, documentation: { type: 'Boolean', desc: 'Deprecated. Git packfile bitmap creation is always enabled. Always returns `true`.' }) { |_settings, _options| true }

      # These fields are deprecated and always returns housekeeping_optimize_repository_period value
      expose(:housekeeping_full_repack_period) { |settings, _options| settings.housekeeping_optimize_repository_period }
      expose(:housekeeping_gc_period) { |settings, _options| settings.housekeeping_optimize_repository_period }
      expose(:housekeeping_incremental_repack_period) { |settings, _options| settings.housekeeping_optimize_repository_period }
      expose(:repository_storages_weighted, documentation: OBJECT) do |settings, _options|
        settings.repository_storages_with_default_weight
      end

      # Expose the source of the product usage data setting (environment or database)
      expose(:gitlab_product_usage_data_source, documentation: { type: 'String', desc: 'Source of the `gitlab_product_usage_data_enabled` setting. Returns `environment` if the `GITLAB_PRODUCT_USAGE_DATA_ENABLED` environment variable is set, otherwise `database`.' }) { |_settings, _options| Gitlab::Usage::ProductUsageDataSetting.source.to_s }
      expose(:gitlab_product_usage_data_enabled) { |_settings, _options| Gitlab::Usage::ProductUsageDataSetting.enabled? }

      # We are ignoring the container registry migration-related database columns.
      # To be backwards compatible, we are keeping these fields in the API
      # but we nullify them. We will eventually remove these as part of
      # https://gitlab.com/gitlab-org/gitlab/-/issues/409873
      {
        container_registry_import_max_tags_count: 0,
        container_registry_import_max_retries: 0,
        container_registry_import_start_max_retries: 0,
        container_registry_import_max_step_duration: 0,
        container_registry_pre_import_tags_rate: 0,
        container_registry_pre_import_timeout: 0,
        container_registry_import_timeout: 0,
        container_registry_import_target_plan: '',
        container_registry_import_created_before: ''
      }.each { |field, value| expose(field) { |_, _| value } }
    end
  end
end

API::Entities::ApplicationSetting.prepend_mod_with('API::Entities::ApplicationSetting')
