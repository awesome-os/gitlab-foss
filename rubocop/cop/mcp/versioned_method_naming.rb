# frozen_string_literal: true

module RuboCop
  module Cop
    module Mcp
      # Enforces the `v` prefix in version-specific MCP method names.
      #
      # Mcp::Tools::Concerns::Versionable dispatches versioned methods as
      # `perform_v<version>` and `build_variables_v<version>`. Legacy method
      # names without the `v` are unreachable and can silently fall back to
      # default behavior.
      #
      # @example
      #
      #   # bad
      #   def perform_0_1_0(arguments)
      #   end
      #
      #   def build_variables_0_1_0
      #   end
      #
      #   # good
      #   def perform_v0_1_0(arguments)
      #   end
      #
      #   def build_variables_v0_1_0
      #   end
      class VersionedMethodNaming < RuboCop::Cop::Base
        extend RuboCop::Cop::AutoCorrector

        MSG = 'Use `%<corrected>s`; version dispatch only calls MCP methods with the `v` prefix.'
        LEGACY_VERSIONED_METHOD = /\A(perform|build_variables)_(\d+_\d+_\d+)\z/

        def on_def(node)
          check_method_name(node.method_name, node.loc.name)
        end

        alias_method :on_defs, :on_def

        def on_send(node)
          return if node.receiver && !node.receiver.self_type?

          check_method_name(node.method_name, node.loc.selector)
        end
        alias_method :on_csend, :on_send

        private

        def check_method_name(method_name, location)
          match = LEGACY_VERSIONED_METHOD.match(method_name.to_s)
          return unless match

          corrected_name = "#{match[1]}_v#{match[2]}"
          add_offense(location, message: format(MSG, corrected: corrected_name)) do |corrector|
            corrector.replace(location, corrected_name)
          end
        end
      end
    end
  end
end
