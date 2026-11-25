# frozen_string_literal: true

module CreatesCommit
  extend ActiveSupport::Concern
  include Gitlab::Utils::StrongMemoize
  include SafeFormatHelper
  include ActionView::Helpers::SanitizeHelper

  # Creates a commit in the requested project or the current user's fork.
  #
  # @param service [Class] Commit service to execute
  # @param success_path [String, Proc] Path used after a successful commit
  # @param failure_path [String, Proc] Path used after a failed commit
  # @param failure_view [Symbol, nil] View rendered after a failed commit
  # @param success_notice [String, Proc, nil] Flash notice used after a successful commit
  # @param target_project [Project, nil] Requested commit destination
  # @param branch_name_generator [Proc, nil] Generates a branch name for the candidate destination before its
  #   branch-specific permission check, and again if the destination falls back to the current user's fork
  # rubocop:disable Gitlab/ModuleWithInstanceVariables
  def create_commit(
    service, success_path:, failure_path:, failure_view: nil, success_notice: nil, target_project: nil,
    branch_name_generator: nil
  )
    target_project ||= @project
    @branch_name = branch_name_from_generator(branch_name_generator, target_project, fallback: @branch_name)

    if user_access(target_project).can_push_to_branch?(branch_name_or_ref)
      @project_to_commit_into = target_project
      @different_project = false
      @branch_name ||= default_branch_name(target_project)
    else
      @project_to_commit_into = current_user.fork_of(target_project)
      @different_project = true
      @branch_name = branch_name_from_generator(
        branch_name_generator, @project_to_commit_into, fallback: @branch_name
      )
      @branch_name ||= generated_branch_name(@project_to_commit_into)
    end

    assign_start_ref

    commit_params = @commit_params.merge(
      start_project: @project_to_commit_into,
      start_branch: @start_branch,
      start_sha: @start_sha,
      source_project: @project,
      target_project: target_project,
      branch_name: @branch_name
    )

    result = service.new(@project_to_commit_into, current_user, commit_params).execute

    if result[:status] == :success
      success_path = final_success_path(success_path, target_project)
      success_notice = success_notice.call if success_notice.respond_to?(:call)

      update_flash_notice(success_notice, success_path)

      respond_to do |format|
        format.html { redirect_to success_path }
        format.json { render json: { message: _("success"), filePath: success_path } }
      end
    else
      failure_path = failure_path.call if failure_path.respond_to?(:call)

      respond_to do |format|
        format.html do
          flash[:alert] = flash_message(result, @project, @branch_name, @commit_params)
          if failure_view
            render failure_view
          else
            redirect_to failure_path
          end
        end
        format.json do
          render json: {
            error: result[:message],
            filePath: failure_path
          }, status: :unprocessable_entity
        end
      end
    end
  end
  # rubocop:enable Gitlab/ModuleWithInstanceVariables

  def authorize_edit_tree!
    return if can_collaborate_with_project?(project, ref: branch_name_or_ref)

    access_denied!
  end

  def format_flash_notice(message)
    formatted_message = message.gsub("\n", "<br>")
    sanitize(formatted_message, tags: %w[br])
  end

  private

  # Resolves a destination-specific branch name without changing the fallback when no destination is available.
  #
  # @param generator [Proc, nil] Destination-aware branch-name generator
  # @param project [Project, nil] Candidate commit destination
  # @param fallback [String, nil] Branch name retained when generation is unavailable
  # @return [String, nil]
  def branch_name_from_generator(generator, project, fallback: nil)
    return fallback unless generator && project

    generator.call(project)
  end

  def flash_message(result, project, branch_name, commit_params)
    if result[:status] == :error && commit_params[:revert]
      {
        message: format_flash_notice(result[:message]),
        button_text: _('Create merge request'),
        button_path: project_new_merge_request_path(
          project,
          merge_request: { source_branch: branch_name }
        )
      }
    else
      format_flash_notice(result[:message])
    end
  end

  def generated_branch_name(project)
    return unless project

    project.repository.next_branch('patch')
  end

  def update_flash_notice(success_notice, success_path)
    changes_link = ActionController::Base.helpers.link_to _('changes'), success_path, class: 'gl-link'

    default_message = safe_format(_("Your %{changes_link} have been committed successfully."),
      changes_link: changes_link)

    flash[:notice] = success_notice || default_message

    if create_merge_request?
      flash[:notice] =
        if merge_request_exists?
          nil
        else
          mr_message =
            if @different_project # rubocop:disable Gitlab/ModuleWithInstanceVariables
              _("You can now submit a merge request to get this change into the original project.")
            elsif @start_sha # rubocop:disable Gitlab/ModuleWithInstanceVariables -- set by assign_start_ref
              _("You can now submit a merge request to get this change into the default branch.")
            else
              _("You can now submit a merge request to get this change into the original branch.")
            end

          flash[:notice] += " #{mr_message}"
        end
    end
  end

  def final_success_path(success_path, target_project)
    if create_merge_request?
      merge_request_exists? ? existing_merge_request_path : new_merge_request_path(target_project)
    else
      success_path = success_path.call if success_path.respond_to?(:call)

      success_path
    end
  end

  # rubocop:disable Gitlab/ModuleWithInstanceVariables
  def new_merge_request_path(_target_project)
    project_new_merge_request_path(
      @project_to_commit_into,
      merge_request: {
        target_project_id: @project_to_commit_into.default_merge_request_target.id,
        source_branch: @branch_name,
        target_branch: merge_request_target_branch
      },
      **new_merge_request_extra_params
    )
  end

  # Commits started from a commit SHA have no start branch, so target the default branch.
  def merge_request_target_branch
    @start_branch || @project_to_commit_into.default_merge_request_target.default_branch
  end
  # rubocop:enable Gitlab/ModuleWithInstanceVariables

  # Override to add context about the commit that seeded the branch. Kept out of
  # the `merge_request` hash because these are not merge request attributes.
  def new_merge_request_extra_params
    {}
  end

  def existing_merge_request_path
    project_merge_request_path(@project, @merge_request) # rubocop:disable Gitlab/ModuleWithInstanceVariables
  end

  # rubocop:disable Gitlab/ModuleWithInstanceVariables
  # rubocop: disable CodeReuse/ActiveRecord
  def merge_request_exists?
    MergeRequestsFinder.new(current_user, project_id: @project.id)
        .execute
        .opened
        .find_by(
          source_project_id: @project_to_commit_into,
          source_branch: @branch_name,
          target_branch: merge_request_target_branch)
  end
  strong_memoize_attr :merge_request_exists?
  # rubocop: enable CodeReuse/ActiveRecord
  # rubocop:enable Gitlab/ModuleWithInstanceVariables

  def create_merge_request?
    # Skip the merge request when the source is the target branch in the same project.
    # FIXME: We should use either 1 or true, not both.
    ActiveModel::Type::Boolean.new.cast(create_merge_request_param) &&
      (@different_project || @start_branch != @branch_name) # rubocop:disable Gitlab/ModuleWithInstanceVariables
  end

  def create_merge_request_param
    params.permit(:create_merge_request)[:create_merge_request]
  end

  def branch_name_or_ref
    @branch_name || @ref # rubocop:disable Gitlab/ModuleWithInstanceVariables
  end

  # rubocop:disable Gitlab/ModuleWithInstanceVariables -- reads and sets the commit state that create_commit shares
  def commit_sha_ref?
    Gitlab::Git.commit_id?(@ref.to_s) && !@project.repository.branch_exists?(@ref)
  end

  def default_branch_name(project)
    commit_sha_ref? ? generated_branch_name(project) : @ref
  end

  # Commits made at a commit SHA start a new branch from that commit.
  def assign_start_ref
    if !@different_project && commit_sha_ref?
      @start_sha = @ref
    else
      @start_branch ||= @ref || @branch_name
    end
  end
  # rubocop:enable Gitlab/ModuleWithInstanceVariables
end
