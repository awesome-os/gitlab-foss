# frozen_string_literal: true

module Ci
  # Defines `runners_token`, the runner registration token of a group or a project.
  module RunnersTokenAuthenticatable
    extend ActiveSupport::Concern
    include ::TokenAuthenticatable

    class_methods do
      private

      # @param routing_payload [Hash{Symbol => Proc}] the owner's routing key, such as `g:` or `p:`, next to `o:`
      def add_runners_token_field(**routing_payload)
        add_authentication_token_field :runners_token,
          encrypted: :required,
          format_with_prefix: :runners_token_prefix,
          require_prefix_for_validation: true,
          routable_token: {
            if: ->(token_owner_record) {
              ::Feature.enabled?(
                :routable_runner_registration_token, token_owner_record.root_ancestor, type: :gitlab_com_derisk
              )
            },
            payload: {
              o: ->(token_owner_record) { token_owner_record.organization_id },
              **routing_payload
            }
          }
      end
    end
  end
end
