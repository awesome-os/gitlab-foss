# frozen_string_literal: true

module API
  module Helpers
    module SuggestionsHelpers
      # @note Overridden in EE, which refuses MCP requests on files excluded from GitLab Duo context.
      def check_suggestion_ai_context_exclusion!(_suggestion); end
    end
  end
end

API::Helpers::SuggestionsHelpers.prepend_mod_with('API::Helpers::SuggestionsHelpers')
