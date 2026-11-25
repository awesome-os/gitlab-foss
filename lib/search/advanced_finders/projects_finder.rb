# frozen_string_literal: true

module Search
  module AdvancedFinders
    class ProjectsFinder
      def initialize(current_user, params = {})
        @current_user = current_user
        @params = params
      end

      # Overwritten in ee/lib/ee/search/advanced_finders/projects_finder.rb
      def use_elasticsearch_finder?
        false
      end
    end
  end
end

Search::AdvancedFinders::ProjectsFinder.prepend_mod
