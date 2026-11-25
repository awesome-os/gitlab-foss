# frozen_string_literal: true

module Gitlab
  module ImportExport
    class DesignRepoRestorer < RepoRestorer
      extend ::Gitlab::Utils::Override

      override :repository
      def repository
        @repository ||= ::DesignManagement.repository_for(importable)
      end

      # `restore` method is handled in super class
    end
  end
end
