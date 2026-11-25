# frozen_string_literal: true

module Types
  module Wikis
    # rubocop: disable Graphql/AuthorizeTypes -- authorized through the parent WikiPage
    class WikiPageVersionType < BaseObject
      graphql_name 'WikiPageVersion'
      description 'A version of a wiki page'

      authorize_granular_token parent_authorizes: :read_wiki

      connection_type_class Types::CountableConnectionType

      field :sha, GraphQL::Types::String,
        null: false, description: 'SHA of the commit that created the version.'

      field :author_name, GraphQL::Types::String,
        null: true, description: 'Name of the author of the version.'

      field :message, GraphQL::Types::String,
        null: true, description: 'Commit message of the version.'

      field :authored_date, Types::TimeType,
        null: true, description: 'Timestamp of when the version was authored.'
    end
    # rubocop: enable Graphql/AuthorizeTypes
  end
end
