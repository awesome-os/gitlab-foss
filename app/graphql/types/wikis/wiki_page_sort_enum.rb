# frozen_string_literal: true

module Types
  module Wikis
    class WikiPageSortEnum < BaseEnum
      graphql_name 'WikiPageSort'
      description 'Values for sorting wiki pages.'

      value 'PATH_ASC', 'Path by ascending order.', value: ::Wiki::DIRECTION_ASC
      value 'PATH_DESC', 'Path by descending order.', value: ::Wiki::DIRECTION_DESC
    end
  end
end
