# frozen_string_literal: true

module Layouts
  class StaticPanelComponent < ViewComponent::Base
    # @param [Hash] html_options
    # @param [Hash] container_options
    # @param [Hash] main_options
    # @param [Boolean] page_breadcrumbs_in_top_bar_feature_flag
    def initialize(
      html_options: {},
      container_options: {},
      main_options: {},
      page_breadcrumbs_in_top_bar_feature_flag: false
    )
      @html_options = html_options
      @container_options = container_options
      @main_options = main_options
      @page_breadcrumbs_in_top_bar_feature_flag = page_breadcrumbs_in_top_bar_feature_flag
    end

    renders_one :header
    renders_one :actions
    renders_one :before_body
    renders_one :body
    renders_one :after_body
    renders_one :footer

    private

    def panel_classes
      class_names('static-panel--headerless': @page_breadcrumbs_in_top_bar_feature_flag)
    end

    def panel_header_bar_classes
      class_names('without-breadcrumbs': @page_breadcrumbs_in_top_bar_feature_flag)
    end

    # @note PanelActionsPortal sets aria-label from data-label when it mounts actions
    def actions_landmark_attributes
      label = _('Page actions')

      { 'aria-label': (label if actions.to_s.present?), data: { label: label } }
    end
  end
end
