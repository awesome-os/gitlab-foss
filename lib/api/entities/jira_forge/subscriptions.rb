# frozen_string_literal: true

module API
  module Entities
    module JiraForge
      class Subscriptions < Grape::Entity
        # rubocop:disable API/EntityFieldType -- SubscriptionEntity is the serializer the Jira Connect app also uses
        expose :subscriptions, using: ::JiraConnect::SubscriptionEntity, documentation: { is_array: true }
        # rubocop:enable API/EntityFieldType
      end
    end
  end
end
