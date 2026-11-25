# frozen_string_literal: true

module Gitlab
  module PolicyStore
    class Policy
      ACTIVE = 'active'

      attr_reader :id, :organization_id, :namespace_id, :name, :description, :version,
        :trigger_type, :rules, :actions, :policy_scope, :scope_rego, :scope_dimensions, :violation_details, :mode,
        :lifecycle_state, :created_at, :updated_at

      # What the update that returned this policy changed. Empty for any other
      # read, and not part of the policy's value.
      attr_reader :changed_attribute_names

      # rubocop:disable Metrics/ParameterLists -- value object; one keyword per field
      def initialize(
        id:, organization_id:, name:, trigger_type:, namespace_id: nil, version: 1,
        description: nil, rules: [], actions: [], policy_scope: nil, scope_rego: nil,
        scope_dimensions: nil, violation_details: [], mode: 'warn', lifecycle_state: 'active',
        created_at: nil, updated_at: nil, changed_attribute_names: [])
        # rubocop:enable Metrics/ParameterLists
        @id = id
        @organization_id = organization_id
        @namespace_id = namespace_id
        @name = name
        @description = description
        @version = version
        @trigger_type = trigger_type
        @rules = rules
        @actions = actions
        @policy_scope = policy_scope
        @scope_rego = scope_rego
        @scope_dimensions = scope_dimensions
        @violation_details = violation_details
        @mode = mode
        @lifecycle_state = lifecycle_state
        @created_at = created_at
        @updated_at = updated_at
        @changed_attribute_names = changed_attribute_names.dup.freeze

        freeze
      end

      def active?
        lifecycle_state == ACTIVE
      end

      def to_h
        {
          id: id,
          organization_id: organization_id,
          namespace_id: namespace_id,
          name: name,
          description: description,
          version: version,
          trigger_type: trigger_type,
          rules: rules,
          actions: actions,
          policy_scope: policy_scope,
          scope_rego: scope_rego,
          scope_dimensions: scope_dimensions,
          violation_details: violation_details,
          mode: mode,
          lifecycle_state: lifecycle_state,
          created_at: created_at,
          updated_at: updated_at
        }
      end

      def ==(other)
        other.is_a?(self.class) && other.to_h == to_h
      end
      alias_method :eql?, :==

      def hash
        to_h.hash
      end
    end
  end
end
