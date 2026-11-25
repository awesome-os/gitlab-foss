# frozen_string_literal: true

module Gitlab
  module Ci
    module Variables
      class Collection
        class Sort
          include TSort
          include Gitlab::Utils::StrongMemoize

          def initialize(collection)
            raise(ArgumentError, "A Gitlab::Ci::Variables::Collection object was expected") unless
              collection.is_a?(Collection)

            @collection = collection
          end

          def valid?
            errors.nil?
          end

          # errors sorts an array of variables, ignoring unknown variable references,
          # and returning an error string if a circular variable reference is found
          def errors
            # Check for cyclic dependencies and build error message in that case
            cyclic_vars = strongly_connected_components.filter_map do |component|
              component.map { |v| v[:key] }.inspect if component.size > 1
            end

            "circular variable reference detected: #{cyclic_vars.join(', ')}" if cyclic_vars.any?
          end
          strong_memoize_attr :errors

          # Overrides TSort#tsort to reuse the components already computed for #errors.
          # A component holds one variable unless it is part of a cycle, which #valid? rules out.
          def tsort
            raise TSort::Cyclic, "topological sort failed: #{errors}" unless valid?

            strongly_connected_components.map(&:first)
          end

          private

          def strongly_connected_components
            each_strongly_connected_component.to_a
          end
          strong_memoize_attr :strongly_connected_components

          def tsort_each_node(&block)
            @collection.each(&block)
          end

          def tsort_each_child(var_item, &block)
            depends_on = var_item.depends_on
            return unless depends_on

            depends_on.filter_map { |var_ref_name| @collection.all(var_ref_name) }.flatten.each(&block)
          end
        end
      end
    end
  end
end
