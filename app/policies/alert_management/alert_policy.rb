# frozen_string_literal: true

module AlertManagement
  class AlertPolicy < ::BasePolicy
    delegate { @subject.project }

    rule { can?(:read_alert_management_alert) }.policy do
      enable :read_alert_metric_image
    end

    rule { can?(:update_alert_management_alert) }.policy do
      enable :create_alert_metric_image
      enable :update_alert_metric_image
      enable :delete_alert_metric_image
    end
  end
end
