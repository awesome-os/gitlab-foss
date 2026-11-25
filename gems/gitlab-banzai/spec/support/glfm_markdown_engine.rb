# frozen_string_literal: true

require 'gitlab-glfm-markdown'

module Banzai
  module Filter
    module MarkdownEngines
      # Stands in for the monolith's engine of the same name, which reads feature
      # flags and the project from the context. It renders with the parser options
      # that the filters specced here depend on.
      class GlfmMarkdown < Base
        OPTIONS = {
          autolink: true,
          footnotes: true,
          inapplicable_tasks: true,
          relaxed_tasklist_character: true,
          sourcepos: true,
          table: true,
          tasklist: true,
          tasklist_classes: true,
          tasklist_in_table: true,
          unsafe: true
        }.freeze

        OPTIONS_NO_SOURCEPOS = OPTIONS.merge(sourcepos: false).freeze

        def render(text)
          # GLFMMarkdown raises on non-UTF-8; `1.to_s` and similar give US-ASCII.
          text = text.encode(Encoding::UTF_8) unless text.encoding == Encoding::UTF_8

          ::GLFMMarkdown.to_html(text, options: sourcepos_disabled? ? OPTIONS_NO_SOURCEPOS : OPTIONS)
        end
      end
    end
  end
end
