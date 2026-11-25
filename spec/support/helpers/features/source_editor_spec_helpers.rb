# frozen_string_literal: true

# These helpers help you interact within the Source Editor (single-file editor, snippets, etc.).
#
module Features
  module SourceEditorSpecHelpers
    def editor_set_value(value)
      editor = find('.monaco-editor')

      # WebDriver waits for the returned promise, and raises if it rejects.
      page.evaluate_script(
        'loadLocalMonaco().then((editor) => editor.getModel(arguments[0]).setValue(arguments[1]))',
        editor['data-uri'],
        value
      )

      # We only check that the first line is present because when the content is long,
      # only a part of the text will be rendered in the DOM due to scrolling
      page.has_selector?('.gl-source-editor .view-lines', text: value.lines.first)
    end
  end
end
