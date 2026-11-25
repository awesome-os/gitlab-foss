# frozen_string_literal: true

require_relative 'project_helper'

module Tooling
  module Danger
    # Prepended to the gitlab-dangerfiles `Danger::Changelog` plugin.
    module Changelog
      EE_CHANGES_REGEX = %r{\A#{ProjectHelper::DOMAIN_PREFIX}ee/}

      def ee_changes
        helper.changed_files(EE_CHANGES_REGEX)
      end
    end
  end
end
