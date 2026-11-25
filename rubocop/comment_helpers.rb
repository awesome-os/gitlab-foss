# frozen_string_literal: true

module RuboCop
  module CommentHelpers
    INDENTED = /\A#\s{2,}\S/
    SKIP = /\A#(!|#?\s*\z|\s*noinspection\b|\s*rubocop\s*:\s*(disable|enable|todo|push|pop|next)\b)/
    YARD_TAGS = %w[
      abstract api attr attr_reader attr_writer attribute author deprecated endgroup example group macro method note
      option overload param parse private raise return scope see since todo version visibility yield yieldparam
      yieldreturn
    ].freeze
    YARD_TAG = /\A#\s*@!?(#{YARD_TAGS.join('|')})\b/

    def skip_comment?(comment)
      comment.text.match?(SKIP) || MagicComment.parse(comment.text).any?
    end
  end
end
