# frozen_string_literal: true

module Onboarding
  module FeatureLibrary
    # Builds the Feature catalog Explore pages for one viewer: the pages their plan can still
    # upgrade to, each filtered to what the plan adds, with the page's upgrade CTA.
    class ExplorePagesBuilder
      include Gitlab::Routing

      PLAN_NAMES = { free: N_('Free'), premium: N_('Premium'), ultimate: N_('Ultimate') }.freeze

      # Compute minutes included a month on GitLab.com, per plan. Product confirmation is tracked in
      # https://gitlab.com/gitlab-org/gitlab/-/work_items/632721.
      COMPUTE_MINUTES = { free: 400, premium: 10_000, ultimate: 50_000 }.freeze

      PAGE_COPY = {
        premium: {
          title: N_('FeatureLibrary|Explore Premium features'),
          subtitle: N_('FeatureLibrary|Control merges and plan work across teams'),
          highlights_title: N_('FeatureLibrary|Premium highlights'),
          ee_migration_notice: N_('FeatureLibrary|To use these features, migrate to Enterprise Edition and upgrade ' \
            'to Premium. %{linkStart}Learn more%{linkEnd}')
        },
        ultimate: {
          title: N_('FeatureLibrary|Explore Ultimate features'),
          subtitle: N_('FeatureLibrary|All of Premium, plus security, analytics, and more'),
          highlights_title: N_('FeatureLibrary|Ultimate highlights'),
          ee_migration_notice: N_('FeatureLibrary|To use these features, migrate to Enterprise Edition and upgrade ' \
            'to Ultimate. %{linkStart}Learn more%{linkEnd}')
        }
      }.freeze

      CREDITS_TITLE = N_('FeatureLibrary|Powered by GitLab Credits')

      LABEL_TEXT = {
        'new' => {
          premium: N_('FeatureLibrary|New with Premium'),
          ultimate: N_('FeatureLibrary|New with Ultimate')
        },
        'enhanced' => {
          premium: N_('FeatureLibrary|Enhanced with Premium'),
          ultimate: N_('FeatureLibrary|Enhanced with Ultimate')
        }
      }.freeze

      ADD_ON_LABEL_TEXT = N_('FeatureLibrary|Add-on')
      EE_MIGRATION_NOTICE_LINK_LABEL = N_('FeatureLibrary|Learn more about GitLab Community Edition')

      def self.available?(user:, resource:)
        return false unless user && resource&.persisted?
        return false unless ::Feature.enabled?(:feature_catalog_explore_pages, resource.root_ancestor)
        return false unless Ability.allowed?(user, :read_feature_catalog_explore_page, resource)

        CurrentPlanContext.new(resource: resource).has_upgrade_pages?
      end

      def initialize(user:, resource:, panel:)
        @user = user
        @resource = resource
        @panel = panel.to_sym
      end

      def execute
        {
          current_plan_context: plan_context.to_h,
          pages: plan_context.tier_pages.map { |plan| page(plan) }
        }
      end

      private

      attr_reader :user, :resource, :panel

      def plan_context
        @plan_context ||= CurrentPlanContext.new(resource: resource)
      end

      def base_plan
        plan_context.base_plan
      end

      def explore_pages
        @explore_pages ||= Catalog.explore_pages(panel: panel, deployment: plan_context.deployment)
      end

      def page(plan)
        explore_page = explore_pages.fetch(plan)
        values = description_values(plan)
        copy = PAGE_COPY.fetch(plan)

        {
          plan: plan,
          title: s_(copy[:title]),
          subtitle: s_(copy[:subtitle]),
          highlights_title: s_(copy[:highlights_title]),
          credits_title: s_(CREDITS_TITLE),
          notice: ee_migration_notice(copy),
          cta: UpgradeCta.new(user: user, resource: resource, plan: plan, base_plan: base_plan).build,
          # The highlights heading names the plan, so highlight cards carry no label.
          highlights: explore_page.highlights.map { |capability| capability_item(capability, values) },
          credits: explore_page.credits.map do |capability|
            capability_item(capability, values).merge(label: label('add_on', plan))
          end,
          categories: categories(explore_page, plan)
        }
      end

      def ee_migration_notice(copy)
        return unless plan_context.edition == :ce

        {
          text: s_(copy[:ee_migration_notice]),
          url: promo_url(path: '/gitlab-community-edition/'),
          link_label: s_(EE_MIGRATION_NOTICE_LINK_LABEL)
        }
      end

      # Items the viewer's plan already includes are left out. Add-ons are never included in a plan.
      # Nav items come first in each category, then enhancements, both in catalog order.
      def categories(explore_page, plan)
        new_items = explore_page.new_items.reject { |item| plan_context.includes_tier?(item.tier) }
        enhancements = explore_page.enhanced_items.reject do |enhancement|
          plan_context.includes_tier?(enhancement.tier)
        end

        new_items_by_category = new_items.group_by(&:category)
        enhancements_by_category = enhancements.group_by { |enhancement| enhancement.nav_item.category }

        Catalog::CATEGORIES.filter_map do |id, title|
          items = new_items_by_category.fetch(id, []).map { |item| nav_item(item, plan) } +
            enhancements_by_category.fetch(id, []).map { |enhancement| enhancement_item(enhancement, plan) }
          next if items.empty?

          { id: id, title: s_(title), items: items }
        end
      end

      def nav_item(item, plan)
        {
          id: item.item_id,
          source: 'nav_item',
          title: item.translated_title,
          description: item.translated_description,
          icon: item.icon,
          docs_url: docs_url(item.docs_path),
          label: label(item.tier == :add_on ? 'add_on' : 'new', plan)
        }
      end

      def enhancement_item(enhancement, plan)
        nav_item(enhancement.nav_item, plan).merge(
          description: enhancement.text,
          label: label('enhanced', plan)
        )
      end

      def capability_item(capability, values)
        {
          id: capability.id,
          source: 'capability',
          title: capability.translated_title,
          description: capability.translated_description(**values),
          icon: capability.icon,
          docs_url: docs_url(capability.docs_path)
        }
      end

      def label(type, plan)
        text = type == 'add_on' ? ADD_ON_LABEL_TEXT : LABEL_TEXT.fetch(type).fetch(plan)

        { type: type, plan: plan, text: s_(text) }
      end

      # Values for the placeholders in capability descriptions. The compute minutes copy compares the
      # page's plan with the viewer's base plan.
      def description_values(plan)
        {
          plan_minutes: COMPUTE_MINUTES.fetch(plan).to_fs(:delimited),
          base_minutes: COMPUTE_MINUTES.fetch(base_plan).to_fs(:delimited),
          base_plan: s_(PLAN_NAMES.fetch(base_plan))
        }
      end

      # A docs_path may end in #section, which becomes the page anchor. The catalog spec checks
      # every docs_path points at an existing page.
      def docs_url(docs_path)
        path, anchor = docs_path.split('#', 2)

        help_page_path(path, anchor: anchor) # rubocop:disable Gitlab/DocumentationLinks/Link -- path comes from the catalog
      end
    end
  end
end
