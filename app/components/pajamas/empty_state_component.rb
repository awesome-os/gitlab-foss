# frozen_string_literal: true

module Pajamas
  class EmptyStateComponent < Pajamas::Component
    HEADER_LEVELS = (1..6).to_a.freeze

    # @param [Boolean] compact
    # @param [String] title
    # @param [String] svg_path
    # @param [String] primary_button_text
    # @param [String] primary_button_link
    # @param [Hash] primary_button_options
    # @param [String] secondary_button_text
    # @param [String] secondary_button_link
    # @param [Hash] secondary_button_options
    # @param [Hash] empty_state_options
    # @param [Integer] header_level
    def initialize(
      compact: false,
      title: nil,
      svg_path: nil,
      primary_button_text: nil,
      primary_button_link: nil,
      primary_button_options: {},
      secondary_button_text: nil,
      secondary_button_link: nil,
      secondary_button_options: {},
      empty_state_options: {},
      header_level: 1
    )
      @compact = compact
      @title = title
      @svg_path = svg_path.to_s
      @primary_button_text = primary_button_text
      @primary_button_link = primary_button_link
      @primary_button_options = primary_button_options
      @secondary_button_text = secondary_button_text
      @secondary_button_link = secondary_button_link
      @secondary_button_options = secondary_button_options
      @empty_state_options = empty_state_options
      @header_level = filter_attribute(header_level, HEADER_LEVELS, default: 1)
    end

    renders_one :title
    renders_one :description
  end
end
