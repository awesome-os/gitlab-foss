# frozen_string_literal: true

module API
  class Suggestions < ::API::Base
    include ::API::Concerns::McpAccess
    include APIGuard

    allow_mcp_access_update

    before { authenticate! }

    feature_category :code_review_workflow

    helpers ::API::Helpers::SuggestionsHelpers

    resource :suggestions do
      desc 'Apply a suggestion to a merge request' do
        detail 'Applies a suggested patch in a merge request. You must have the Developer, ' \
          'Maintainer, or Owner role.'
        success Entities::Suggestion
        tags %w[suggestions]
      end
      params do
        requires :id, type: Integer, desc: 'ID of the suggestion.'
        optional :commit_message, type: String, desc: "Custom commit message to use instead of the generated message or the project's commit message for applied suggestions."
      end
      route_setting :mcp, tool_name: :apply_suggestion, toolset: :merge_requests,
        params: [:id, :commit_message],
        annotations: { title: 'Apply suggestion', readOnlyHint: false, destructiveHint: true,
                       idempotentHint: false, openWorldHint: true },
        # `:id` is a suggestion id here, so the default `project: :id` would look up a project with that id.
        container_arguments: {
          project: :project_id,
          record: { id: ->(id) { ::Suggestion.find_by_id(id)&.then { |s| [s.target_project, s.source_project].uniq } } }
        }
      # The commit lands in the source project and the suggestion lives in the target project.
      route_setting :authorization, permissions: :apply_suggestion,
        boundaries: [
          { boundary: -> { find_suggestion&.noteable&.source_project }, boundary_type: :project },
          { boundary: -> { find_suggestion&.noteable&.target_project }, boundary_type: :project }
        ]
      put ':id/apply', urgency: :low do
        suggestion = find_suggestion

        if suggestion
          apply_suggestions(suggestion, current_user, params[:commit_message])
        else
          render_api_error!(_('Suggestion is not applicable as the suggestion was not found.'), :not_found)
        end
      end

      desc 'Apply multiple suggestions to a merge request' do
        detail 'Applies multiple suggested patches in a merge request. You must have the ' \
          'Developer, Maintainer, or Owner role.'
        success Entities::Suggestion
        tags %w[suggestions]
      end
      params do
        requires :ids, type: Array[Integer], coerce_with: ::API::Validations::Types::CommaSeparatedToIntegerArray.coerce, desc: 'IDs of suggestions to apply.'
        optional :commit_message, type: String, desc: "Custom commit message to use instead of the default generated message or the project's default message."
      end
      route_setting :authorization, permissions: :apply_suggestion,
        boundaries: [
          { boundary: -> { find_suggestions.first&.noteable&.source_project }, boundary_type: :project },
          { boundary: -> { find_suggestions.first&.noteable&.target_project }, boundary_type: :project }
        ]
      put 'batch_apply', urgency: :low do
        ids = params[:ids]

        suggestions = find_suggestions

        if suggestions.size == ids.length
          apply_suggestions(suggestions, current_user, params[:commit_message])
        else
          render_api_error!(_('Suggestions are not applicable as one or more suggestions were not found.'), :not_found)
        end
      end
    end

    helpers do
      def find_suggestion
        @suggestion ||= Suggestion.find_by_id(params[:id])
      end

      def find_suggestions
        @suggestions ||= Suggestion.id_in(params[:ids]).to_a
      end

      def apply_suggestions(suggestions, current_user, message)
        authorize_suggestions(*suggestions)
        Array.wrap(suggestions).each { |suggestion| check_suggestion_ai_context_exclusion!(suggestion) }

        result = ::Suggestions::ApplyService.new(current_user, *suggestions, message: message).execute

        if result[:status] == :success
          present reload_suggestions(suggestions), with: Entities::Suggestion, current_user: current_user
        else
          http_status = result[:http_status] || :bad_request
          render_api_error!(result[:message], http_status)
        end
      end

      # ApplyService marks the suggestions as applied with update_all, which
      # leaves the records loaded here, and what they memoized, as they were.
      def reload_suggestions(suggestions)
        reloaded = Suggestion.id_in(Array.wrap(suggestions).map(&:id)).to_a

        suggestions.is_a?(Array) ? reloaded : reloaded.first
      end

      def authorize_suggestions(*suggestions)
        suggestions.each do |suggestion|
          authorize! :apply_suggestion, suggestion
        end
      end
    end
  end
end
