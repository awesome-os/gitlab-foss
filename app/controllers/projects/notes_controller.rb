# frozen_string_literal: true

class Projects::NotesController < Projects::ApplicationController
  extend Gitlab::Utils::Override
  include RendersNotes
  include NotesActions
  include NotesHelper
  include ToggleAwardEmoji

  before_action :disable_query_limiting, only: [:create, :update]
  before_action :disable_query_limiting_index, only: [:index]

  before_action :authorize_read_note!
  before_action :authorize_create_note!, only: [:create]
  before_action :check_merge_request_notes_poll_rate_limit!, only: [:index]

  feature_category :team_planning, [:index, :create, :update, :destroy, :toggle_award_emoji]
  feature_category :code_review_workflow, [:outdated_line_change]
  urgency :low

  override :feature_category
  def feature_category
    if %w[index create].include?(action_name)
      category = feature_category_override_for_target_type(permitted_params[:target_type])
      return category if category
    end

    super
  end

  def feature_category_override_for_target_type(target_type)
    case target_type
    when 'merge_request'
      'code_review_workflow'
    when 'commit', 'project_snippet'
      'source_code_management'
    end
  end

  def outdated_line_change
    diff_lines = Rails.cache.fetch(['note', note.id, 'oudated_line_change'], expires_in: 7.days) do
      Gitlab::Json.dump(::MergeRequests::OutdatedDiscussionDiffLinesService.new(project: note.noteable.source_project,
        note: note).execute)
    end

    render json: diff_lines
  end

  private

  def permitted_params
    params.permit(:id, :target_type)
  end

  def note
    @note ||= @project.notes.find(permitted_params[:id])
  end

  alias_method :awardable, :note

  # Keys read by NotesFinder that the client may supply; the rest are set explicitly below.
  # :target is deliberately absent, it is a noteable object rather than a request value.
  def finder_params
    params.permit(:target_type, :target_id, :target_iid, :search, :sort, :group_id).merge(
      organization_id: Current.organization.id,
      project: project,
      last_fetched_at: last_fetched_at,
      notes_filter: notes_filter
    )
  end

  def authorize_create_note!
    return unless noteable.lockable?

    access_denied! unless can?(current_user, :create_note, noteable)
  end

  # The caller picks X-Last-Fetched-At, so every poll can return a full page of notes.
  def check_merge_request_notes_poll_rate_limit!
    return if current_user
    return unless noteable.is_a?(MergeRequest)

    check_rate_limit!(:merge_request_notes_index_unauthenticated, scope: { ip: request.ip })
  end

  def disable_query_limiting_index
    Gitlab::QueryLimiting.disable!('https://gitlab.com/gitlab-org/gitlab/-/issues/460923')
  end

  def disable_query_limiting
    Gitlab::QueryLimiting.disable!('https://gitlab.com/gitlab-org/gitlab/-/issues/211538', new_threshold: 310)
  end
end
