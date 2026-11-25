# frozen_string_literal: true

module Layouts
  class DetailLayout < Layouts::BaseLayout
    # @param [Boolean] sidebar_first puts the sidebar before the content in the DOM at every width,
    #   so it shows on top when the layout stacks
    # @param [String] sidebar_label accessible name of the sidebar landmark, defaults to "Sidebar"
    def initialize(sidebar_first: false, sidebar_label: nil, **base_options)
      super(**base_options)
      @sidebar_first = sidebar_first
      @sidebar_label = sidebar_label
    end

    renders_one :sidebar
    renders_one :widgets
    renders_one :activity

    private

    # @note Keep in sync with the sidebar in detail_layout.vue
    def sidebar_attributes
      {
        class: 'js-detail-layout-sidebar',
        tabindex: 0,
        'aria-label': @sidebar_label.presence || _('Sidebar'),
        data: { testid: 'detail-layout-sidebar' }
      }
    end
  end
end
