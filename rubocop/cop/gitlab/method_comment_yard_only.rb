# frozen_string_literal: true

require_relative '../../comment_helpers'

module RuboCop
  module Cop
    module Gitlab
      # Allows only YARD tags in the comment block directly above a method.
      # See https://docs.gitlab.com/development/code_comments/#class-and-method-documentation
      #
      # @example
      #   # bad
      #   # Finds a user for the given email.
      #   def find_by_any_email(email); end
      #
      #   # good
      #   # @note Secondary emails are unconfirmed until verified, so they're checked last.
      #   # @param email [String]
      #   # @return [User, nil]
      #   def find_by_any_email(email); end
      class MethodCommentYardOnly < RuboCop::Cop::Base
        include CommentHelpers

        MSG = 'Use only YARD tags in the comment above a method. ' \
          'Put the why in a @note tag and move the rest to the MR or issue. ' \
          'See https://docs.gitlab.com/development/code_comments/#class-and-method-documentation'

        # @!method override?(node)
        def_node_matcher :override?, '(send nil? :override sym)'

        def on_def(node)
          [node.first_line, override_line(node)].compact.each do |line|
            block = comment_block_above(line)
            add_offense(block.last) unless yard_only?(block)
          end
        end
        alias_method :on_defs, :on_def

        private

        def override_line(node)
          sibling = node.left_sibling
          sibling.first_line if override?(sibling)
        end

        def comment_block_above(line)
          numbers = (1...line).reverse_each.take_while do |number|
            comment_line?(processed_source.lines[number - 1]) && processed_source.comment_at_line(number)
          end

          numbers.reverse.map { |number| processed_source.comment_at_line(number) }
        end

        def yard_only?(block)
          in_tag = false

          block.all? do |comment|
            if skip_comment?(comment)
              true
            elsif comment.text.match?(YARD_TAG)
              in_tag = true
            else
              in_tag && comment.text.match?(INDENTED)
            end
          end
        end
      end
    end
  end
end
