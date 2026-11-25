# frozen_string_literal: true

module Groups
  module Settings
    class IntegrationsController < Groups::ApplicationController
      include ::Integrations::Actions

      before_action :authorize_read_integration!, only: :index
      # rubocop:disable Rails/LexicallyScopedActionFilter -- update, test and reset are defined in Integrations::Actions
      before_action :authorize_update_integration!, only: [:edit, :update, :test, :reset]
      # rubocop:enable Rails/LexicallyScopedActionFilter

      before_action only: [:edit] do
        push_frontend_feature_flag(:finer_filters_for_integrations, group)
      end

      feature_category :integrations

      layout 'group_settings'

      def index
        @hide_search_settings = true
        @integrations = Integration
          .find_or_initialize_all_non_project_specific(Integration.for_group(group))
          .select { |integration| integration.class.available_for_group?(group) }
          .sort_by { |integration| integration.title.downcase }
      end

      def edit
        @default_integration = Integration.default_integration(integration.type, group)

        super
      end

      private

      def find_or_initialize_non_project_specific_integration(name)
        group.find_or_initialize_integration(name)
      end
    end
  end
end
