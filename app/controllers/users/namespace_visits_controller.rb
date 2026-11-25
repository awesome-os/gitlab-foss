# frozen_string_literal: true

module Users
  class NamespaceVisitsController < ApplicationController
    feature_category :navigation

    before_action -> { check_rate_limit!(:track_namespace_visits, scope: { user: current_user }) }, only: :create

    def create
      return head :bad_request unless safe_params[:type].present? && safe_params[:id].present?

      Users::TrackNamespaceVisitsWorker.perform_async(safe_params[:type], safe_params[:id], current_user.id, DateTime.now.to_s) # rubocop:disable CodeReuse/Worker
      head :ok
    end

    def safe_params
      params.permit(:type, :id)
    end
  end
end
