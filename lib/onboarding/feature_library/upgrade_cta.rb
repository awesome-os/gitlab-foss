# frozen_string_literal: true

module Onboarding
  module FeatureLibrary
    # The call to action in an Explore page header. CE has no license to upgrade, so instance
    # admins are offered the CE to EE conversion docs instead. EE overrides #build to route by plan and role.
    class UpgradeCta
      include Gitlab::Routing

      # plan is the page the CTA belongs to (:premium or :ultimate). base_plan is the plan the
      # viewer holds, or returns to when a trial ends.
      def initialize(user:, resource:, plan:, base_plan: :free)
        @user = user
        @resource = resource
        @plan = plan
        @base_plan = base_plan
      end

      def build
        return unless user&.can_admin_all_resources?

        {
          type: 'migrate',
          text: s_('FeatureLibrary|Migrate to Enterprise Edition'),
          # A help page path is internal, but the docs it redirects to open in a new tab.
          url: help_page_path('update/convert_to_ee/_index.md', anchor: 'convert-to-enterprise-edition'),
          new_tab: true
        }
      end

      private

      attr_reader :user, :resource, :plan, :base_plan
    end
  end
end

Onboarding::FeatureLibrary::UpgradeCta.prepend_mod
