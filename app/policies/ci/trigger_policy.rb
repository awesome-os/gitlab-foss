# frozen_string_literal: true

module Ci
  class TriggerPolicy < BasePolicy
    delegate { @subject.project }

    with_score 0
    condition(:is_owner) { @user && @subject.owner_id == @user.id }

    rule { ~is_owner }.prevent :_update_owned_trigger
    rule { can?(:_update_owned_trigger) }.enable :update_trigger
  end
end
