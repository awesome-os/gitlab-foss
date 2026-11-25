# frozen_string_literal: true

class Projects::DeployTokensController < Projects::ApplicationController
  before_action :authorize_delete_deploy_token!

  feature_category :continuous_delivery
  urgency :low

  def revoke
    @token = @project.deploy_tokens.find(id_param)
    @token.revoke!

    redirect_to project_settings_repository_path(project, anchor: 'js-deploy-tokens')
  end

  private

  def authorize_delete_deploy_token!
    access_denied! unless can?(current_user, :delete_deploy_token, project)
  end

  def id_param
    params.permit(:id)[:id]
  end
end

Projects::DeployTokensController.prepend_mod
