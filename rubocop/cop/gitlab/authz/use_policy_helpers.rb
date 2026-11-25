# frozen_string_literal: true

module RuboCop
  module Cop
    module Gitlab
      module Authz
        # Detects `allow_action`, `be_allowed`, `be_disallowed` and `be_banned` in policy specs
        # and suggests using `expect_allowed` / `expect_disallowed` from `PolicyHelpers`.
        #
        # Using the helpers wraps assertions in `aggregate_failures` and uses the
        # `allow_action` matcher, which prints a detailed debug trace on failure.
        # `expect_disallowed` also fails when the policy does not define the permission.
        # Multiple permissions can also be checked in a single call.
        #
        # @example
        #   # bad
        #   is_expected.to allow_action(:read_group)
        #   is_expected.not_to be_allowed(:read_group)
        #   expect(policy).to be_disallowed(:read_group)
        #   is_expected.to(allowed ? be_allowed(:read_group) : be_disallowed(:read_group))
        #   is_expected.to send(expected_result, :read_group) # with :be_allowed in a where table
        #   is_expected.to be_banned
        #
        #   # good
        #   expect_allowed(:read_group)
        #   expect_disallowed(:read_group)
        #   allowed ? expect_allowed(:read_group) : expect_disallowed(:read_group)
        #   it_behaves_like 'prevent all'
        #
        class UsePolicyHelpers < ::RuboCop::Cop::Base
          extend AutoCorrector

          MSG = 'Use `expect_allowed` or `expect_disallowed` from `PolicyHelpers` ' \
            'instead of using `allow_action`, `be_allowed`, or `be_disallowed` directly.'
          MSG_BANNED = '`be_banned` passes for any policy with a `prevent_all` rule. ' \
            "Use `it_behaves_like 'prevent all'` or `'prevent all except'` instead."

          MATCHERS = %i[allow_action be_allowed be_disallowed].to_set.freeze

          # @!method permission_matcher?(node)
          def_node_matcher :permission_matcher?, <<~PATTERN
            (send nil? {:allow_action :be_allowed :be_disallowed} ...)
          PATTERN

          # @!method banned_matcher?(node)
          def_node_matcher :banned_matcher?, <<~PATTERN
            (send nil? :be_banned)
          PATTERN

          # Matches: is_expected.to be_allowed(...)
          #          is_expected.not_to allow_action(...)
          # @!method expected_assertion?(node)
          def_node_matcher :expected_assertion?, <<~PATTERN
            (send (send nil? :is_expected) {:to :not_to} (send nil? {:allow_action :be_allowed :be_disallowed} ...))
          PATTERN

          def on_send(node)
            if banned_matcher?(node)
              add_offense(node.loc.selector, message: MSG_BANNED)
            elsif permission_matcher?(node)
              add_offense(node.loc.selector) { |corrector| autocorrect(corrector, node) }
            end
          end
          alias_method :on_csend, :on_send

          # @note Catches matcher names stored as symbols, such as a where table read with send.
          def on_sym(node)
            add_offense(node) if MATCHERS.include?(node.value)
          end

          private

          def autocorrect(corrector, matcher)
            assertion = matcher.parent
            return unless assertion && expected_assertion?(assertion)

            permissions = matcher.arguments.map(&:source).join(', ')
            disallowed = assertion.method?(:not_to) || matcher.method?(:be_disallowed)
            helper = disallowed ? 'expect_disallowed' : 'expect_allowed'
            corrector.replace(assertion, "#{helper}(#{permissions})")
          end
        end
      end
    end
  end
end
