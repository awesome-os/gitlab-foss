# frozen_string_literal: true

module RuboCop
  module Cop
    module API
      # Checks that every endpoint marked `hidden true` records why it is left out of the
      # OpenAPI spec, with `route_setting :lifecycle` or `route_setting :openapi_hidden_reason`
      # on the same endpoint.
      #
      # Grape clears a namespace's route settings after each endpoint directly in it, so a setting
      # at the top of a namespace reaches the first endpoint in it, plus the endpoints in nested
      # namespaces before that one. Put the setting between the previous endpoint and this one.
      #
      # @example
      #
      #   # bad - no reason recorded
      #   desc 'Authorize a file upload' do
      #     hidden true
      #   end
      #   post 'authorize' do
      #   end
      #
      #   # bad - unknown reason
      #   route_setting :openapi_hidden_reason, :unfinished
      #
      #   # good - only other systems call the endpoint
      #   desc 'Authorize a file upload' do
      #     hidden true
      #   end
      #   route_setting :openapi_hidden_reason, :internal
      #   post 'authorize' do
      #   end
      #
      #   # good - the endpoint is not generally available yet
      #   desc 'Create a virtual registry' do
      #     hidden true
      #   end
      #   route_setting :lifecycle, :experiment
      #   post do
      #   end
      class HiddenEndpointReason < RuboCop::Cop::Base
        REASONS = %i[internal other_protocol].freeze
        HTTP_METHODS = %i[get post put patch delete head options route].freeze

        MSG = 'Endpoints marked `hidden true` must record why they are left out of the OpenAPI spec. ' \
          'Add `route_setting :lifecycle` or `route_setting :openapi_hidden_reason` to this endpoint. ' \
          'See https://docs.gitlab.com/development/api_styleguide/#marking-endpoints-as-hidden'

        MSG_REASON = "Invalid OpenAPI hidden reason `%s`. Use one of: #{REASONS.map(&:inspect).join(', ')}.".freeze

        RESTRICT_ON_SEND = %i[desc route_setting].freeze

        # @!method hidden_markers(node)
        def_node_search :hidden_markers, <<~PATTERN
          {(send nil? :hidden true) (pair (sym :hidden) true)}
        PATTERN

        # @!method hidden_reason_setting(node)
        def_node_matcher :hidden_reason_setting, <<~PATTERN
          (send nil? :route_setting (sym :openapi_hidden_reason) $_)
        PATTERN

        # @!method reason_setting?(node)
        def_node_matcher :reason_setting?, <<~PATTERN
          (send nil? :route_setting (sym {:lifecycle :openapi_hidden_reason}) ...)
        PATTERN

        def on_send(node)
          return check_reason_value(node) if node.method?(:route_setting)

          statement = node.block_node || node
          hidden_node = hidden_markers(statement).first
          return unless hidden_node
          return if reason_recorded?(statement)

          add_offense(hidden_node)
        end
        alias_method :on_csend, :on_send

        private

        def check_reason_value(node)
          hidden_reason_setting(node) do |value_node|
            next if value_node.sym_type? && REASONS.include?(value_node.value)

            add_offense(value_node, message: format(MSG_REASON, value_node.source))
          end
        end

        def reason_recorded?(statement)
          pending_settings(statement).any? { |node| reason_setting?(node) }
        end

        # The statements that configure the endpoint this desc describes: in its own block, back to the
        # previous endpoint and forward to this one. In each enclosing block, back to the previous endpoint
        # in that block, because Grape clears a block's settings only after an endpoint directly in it.
        def pending_settings(statement)
          settings = preceding_statements(statement).take_while { |node| !endpoint?(node) } +
            following_statements(statement).take_while { |node| !endpoint?(node) }

          scope = enclosing_block(statement)
          while scope
            preceding = preceding_statements(scope)
            settings += preceding.take_while { |node| !endpoint?(node) }
            break if preceding.any? { |node| endpoint?(node) }

            scope = enclosing_block(scope)
          end

          settings
        end

        # Nearest first.
        def preceding_statements(node)
          node.parent&.begin_type? ? node.left_siblings.reverse : []
        end

        def following_statements(node)
          node.parent&.begin_type? ? node.right_siblings : []
        end

        def enclosing_block(node)
          body = node.parent&.begin_type? ? node.parent : node
          block = body.parent

          block if block&.block_type?
        end

        def endpoint?(node)
          send_node = node.block_type? ? node.send_node : node
          send_node.send_type? && send_node.receiver.nil? && HTTP_METHODS.include?(send_node.method_name)
        end
      end
    end
  end
end
