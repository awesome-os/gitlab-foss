# frozen_string_literal: true

module Projects
  module Settings
    class BranchRulesController < Projects::ApplicationController
      before_action :authorize_read_branch_rule!

      feature_category :repository_services

      def index; end
    end
  end
end

Projects::Settings::BranchRulesController.prepend_mod
