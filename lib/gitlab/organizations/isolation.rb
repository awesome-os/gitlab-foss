# frozen_string_literal: true

module Gitlab
  module Organizations
    class Isolation
      QUERY_SCOPING_ALLOWED_KEY = :gitlab_organizations_query_scoping_allowed

      # Skips the data_isolation feature flag check inside the block. Scoping is
      # allowed here, not guaranteed: the other checks in .enabled? still apply.
      def self.allow_query_scoping
        previous = Thread.current[QUERY_SCOPING_ALLOWED_KEY]
        Thread.current[QUERY_SCOPING_ALLOWED_KEY] = true
        yield
      ensure
        Thread.current[QUERY_SCOPING_ALLOWED_KEY] = previous
      end

      def self.query_scoping_allowed?
        Thread.current[QUERY_SCOPING_ALLOWED_KEY] == true
      end

      # rubocop:disable Gitlab/AvoidCurrentOrganization -- We check if Current.organization is assigned so it is safe
      def self.enabled?
        return false if Gitlab::Database::DataIsolation::Context.disabled?

        enabled_ignoring_context?
      end

      # Only for callers that run inside without_data_isolation and still need the
      # isolation state, such as the Arel strategy building its sharding subquery.
      # Everything that scopes a query wants .enabled? instead.
      def self.enabled_ignoring_context?
        return false unless query_scoping_allowed? || begin
          Feature.enabled?(:data_isolation, Feature.current_request)
        rescue Exception # rubocop:disable Lint/RescueException -- GitLab has Errors that have Exception as parent class
          false
        end

        return false unless ::Current.organization_assigned

        # Disable organization scoping because checking isolation state can raise a ThreadError
        return false unless Gitlab::Database::DataIsolation::ScopeHelper.without_data_isolation do
          ::Current.organization&.isolated?
        end

        true
      end

      def self.organization_isolated?(organization_id)
        return false unless organization_id

        tracker = Gitlab::Organizations::FallbackOrganizationTracker
        current_organization = tracker.without_tracking { ::Current.organization if ::Current.organization_assigned }

        if current_organization&.id == organization_id
          return tracker.without_tracking do
            Gitlab::Database::DataIsolation::ScopeHelper.without_data_isolation { current_organization.isolated? }
          end
        end

        Gitlab::SafeRequestStore.fetch([:organization_isolated, organization_id]) do
          Gitlab::Database::DataIsolation::ScopeHelper.without_data_isolation do
            ::Organizations::OrganizationIsolation.isolated_organization?(organization_id)
          end
        end
      end
      # rubocop:enable Gitlab/AvoidCurrentOrganization
    end
  end
end
