# frozen_string_literal: true

require_relative '../../tooling/danger/project_helper'
require_relative '../../tooling/danger/changelog'

module Danger
  # Common helper functions for our danger scripts. See Tooling::Danger::ProjectHelper
  # for more details
  class ProjectHelper < ::Danger::Plugin
    # Put the helper code somewhere it can be tested
    include Tooling::Danger::ProjectHelper
  end
end

# Gem plugins load before project plugins, but fast specs load this file without the gem's Changelog plugin.
::Danger::Changelog.prepend(::Tooling::Danger::Changelog) if defined?(::Danger::Changelog)
