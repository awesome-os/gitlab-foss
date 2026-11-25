# frozen_string_literal: true

module Profiles
  class SlacksController < Profiles::ApplicationController
    include IntegrationsHelper

    skip_before_action :authenticate_user!

    layout 'application'

    feature_category :integrations

    # The dropdown only searches the projects in the page. Users who maintain more install from the project's settings.
    MAX_INSTALLABLE_PROJECTS = 100

    # The newest projects by id, then sorted by name like the groups: ordering the whole list by name reads every
    # project the user maintains.
    def edit
      return unless current_user

      @projects = disabled_projects.newest_sorted_by_name(MAX_INSTALLABLE_PROJECTS).inc_routes
    end

    def slack_link
      project = disabled_projects.find(params.permit(:project_id)[:project_id])
      link = add_to_slack_link(project, Gitlab::CurrentSettings.slack_app_id)

      render json: { add_to_slack_link: link }
    end

    private

    def disabled_projects
      @disabled_projects ||= current_user
        .authorized_projects(Gitlab::Access::MAINTAINER)
        .with_slack_application_disabled
    end
  end
end

Profiles::SlacksController.prepend_mod
