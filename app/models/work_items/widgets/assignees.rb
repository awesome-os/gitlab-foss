# frozen_string_literal: true

module WorkItems
  module Widgets
    class Assignees < Base
      delegate :assignees, :assignees_by_name_and_id, :allows_multiple_assignees?, to: :work_item

      def self.quick_action_commands
        [:assign, :unassign, :reassign]
      end

      def self.quick_action_params
        [:assignee_ids]
      end

      def self.can_invite_members?(user, resource_parent)
        permission = resource_parent.is_a?(Project) ? :create_project_member : :admin_group_member

        Ability.allowed?(user, permission, resource_parent)
      end
    end
  end
end

WorkItems::Widgets::Assignees.prepend_mod
