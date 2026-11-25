# frozen_string_literal: true

class Projects::TriggersController < Projects::ApplicationController
  before_action :authorize_read_trigger!, only: :index
  before_action :authorize_create_trigger!, only: :create
  before_action :authorize_update_trigger!, only: :update
  before_action :authorize_delete_trigger!, only: :destroy

  before_action :trigger, only: [:update, :destroy]

  layout 'project_settings'

  feature_category :continuous_integration
  urgency :low

  def index
    redirect_to project_settings_ci_cd_path(@project, anchor: 'js-pipeline-triggers')
  end

  def create
    response = ::Ci::PipelineTriggers::CreateService.new(
      project: project,
      user: current_user,
      description: trigger_params[:description],
      expires_at: trigger_params[:expires_at]
    ).execute

    @trigger = response.payload[:trigger]

    if response.success?
      flash[:notice] = _('Trigger token was created successfully.')
    else
      flash[:alert] = response.message
    end

    redirect_to project_settings_ci_cd_path(@project, anchor: 'js-pipeline-triggers')
  end

  def update
    response = ::Ci::PipelineTriggers::UpdateService.new(user: current_user, trigger: trigger,
      description: trigger_params[:description]).execute

    if response.success?
      redirect_to project_settings_ci_cd_path(@project, anchor: 'js-pipeline-triggers'),
        notice: _('Trigger token was successfully updated.')
    else
      render action: "edit"
    end
  end

  def destroy
    response = ::Ci::PipelineTriggers::DestroyService.new(user: current_user, trigger: trigger).execute

    if response.success?
      flash[:notice] = _("Trigger token removed.")
    else
      flash[:alert] = response.message
    end

    redirect_to project_settings_ci_cd_path(@project, anchor: 'js-pipeline-triggers'), status: :found
  end

  private

  def authorize_read_trigger!
    access_denied! unless can?(current_user, :read_trigger, project)
  end

  def authorize_create_trigger!
    access_denied! unless can?(current_user, :create_trigger, project)
  end

  def authorize_update_trigger!
    access_denied! unless can?(current_user, :update_trigger, trigger)
  end

  def authorize_delete_trigger!
    access_denied! unless can?(current_user, :delete_trigger, trigger)
  end

  def trigger
    @trigger ||= project.triggers.find(find_trigger_params[:id])
      .present(current_user: current_user)
  end

  def find_trigger_params
    params.permit(:id)
  end

  def trigger_params
    params.require(:trigger).permit(:description, :expires_at)
  end
end
