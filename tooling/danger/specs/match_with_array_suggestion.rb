# frozen_string_literal: true

require_relative '../suggestion'

module Tooling
  module Danger
    module Specs
      class MatchWithArraySuggestion < Suggestion
        # One array element. Brackets nest, so a comma inside a nested array or hash does not count.
        ELEMENT = /(?:[^\[\]{}(),]|(?<nested>[\[{(](?:[^\[\]{}()]|\g<nested>)*[\]})]))+/
        MATCH = /(?<to>to\(?\s*)(?<matcher>match|eq)(?<expectation>[( ]?\[)(?=#{ELEMENT},)/
        REPLACEMENT = '\k<to>match_array\k<expectation>'
        SUGGESTION = <<~SUGGEST_COMMENT
          If order of the result is not important, please consider using `match_array` to avoid flakiness.
        SUGGEST_COMMENT
      end
    end
  end
end
