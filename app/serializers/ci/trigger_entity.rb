# frozen_string_literal: true

module Ci
  class TriggerEntity < Grape::Entity
    include Gitlab::Routing
    include Gitlab::Allowable

    expose :id
    expose :description
    expose :owner, using: UserEntity
    expose :last_used
    expose :expires_at

    expose :token do |trigger|
      can_update_trigger?(trigger) ? trigger.token : trigger.short_token
    end

    expose :has_token_exposed do |trigger|
      can_update_trigger?(trigger)
    end

    expose :can_access_project, &:can_access_project?

    expose :project_trigger_path, if: ->(trigger) { can_delete_trigger?(trigger) } do |trigger|
      project_trigger_path(options[:project], trigger)
    end

    private

    def can_delete_trigger?(trigger)
      can?(options[:current_user], :delete_trigger, trigger)
    end

    def can_update_trigger?(trigger)
      can?(options[:current_user], :update_trigger, trigger)
    end
  end
end
