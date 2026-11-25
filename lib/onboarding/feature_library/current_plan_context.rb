# frozen_string_literal: true

module Onboarding
  module FeatureLibrary
    # The plan a viewer currently holds and which upgrade pages still apply to them. On CE there is
    # no license, so every viewer is on Free and sees both Explore pages. EE overrides the plan,
    # deployment and trial.
    class CurrentPlanContext
      # Ordered lowest to highest tier: tier_pages returns the plans after the base plan.
      PLANS = %i[free premium ultimate].freeze
      PLAN_RANK = PLANS.each_with_index.to_h.freeze
      PAID_PLANS = %i[premium ultimate].freeze

      # Premium or Ultimate. Free, add-ons and unknown tiers, such as a retired :gold, return false.
      def self.paid_plan_tier?(tier)
        tier.present? && PAID_PLANS.include?(tier.to_sym)
      end

      def initialize(resource:)
        @resource = resource
      end

      def edition
        :ce
      end

      def deployment
        :self_managed
      end

      def current_plan
        :free
      end

      def trial?
        false
      end

      # The plan the Explore pages compare against. EE overrides it for trials.
      def base_plan
        current_plan
      end

      # The plans the viewer can still upgrade to. The Ultimate page is cumulative, so Free sees both.
      def tier_pages
        PLANS.drop(PLANS.index(base_plan) + 1)
      end

      def has_upgrade_pages?
        trial? || tier_pages.any?
      end

      # Whether the base plan includes features of this tier. No plan includes an add-on.
      # Raises on an unknown tier.
      def includes_tier?(tier)
        tier = tier.to_sym
        return false if tier == :add_on

        PLAN_RANK.fetch(tier) <= PLAN_RANK.fetch(base_plan)
      end

      def to_h
        {
          deployment: deployment,
          current_plan: current_plan,
          base_plan: base_plan,
          trial: trial?
        }
      end

      private

      attr_reader :resource
    end
  end
end

Onboarding::FeatureLibrary::CurrentPlanContext.prepend_mod
