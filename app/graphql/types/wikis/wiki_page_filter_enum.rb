# frozen_string_literal: true

module Types
  module Wikis
    class WikiPageFilterEnum < BaseEnum
      graphql_name 'WikiPageFilter'
      description 'Values for filtering wiki pages.'

      value 'ALL', 'All wiki pages, including templates and uploads.', value: 'all'
      value 'PAGES', 'Wiki pages outside the `templates/` and `uploads/` directories.', value: 'pages'
      value 'TEMPLATES', 'Wiki pages in the `templates/` directory.', value: 'templates'
    end
  end
end
