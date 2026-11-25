# frozen_string_literal: true

module Types
  module CiConfiguration
    module Sast
      # rubocop: disable Graphql/AuthorizeTypes
      class AnalyzersEntityType < BaseObject
        graphql_name 'SastCiConfigurationAnalyzersEntity'
        description 'Represents an analyzer entity in SAST CI configuration'

        authorize_granular_token parent_authorizes: :read_security_configuration

        field :name, GraphQL::Types::String, null: true,
          description: 'Name of the analyzer.'

        field :label, GraphQL::Types::String, null: true,
          description: 'Analyzer label used in the config UI.'

        field :enabled, GraphQL::Types::Boolean, null: true,
          description: 'Indicates whether an analyzer is enabled.'

        field :description, GraphQL::Types::String, null: true,
          description: 'Analyzer description that is displayed on the form.'

        field :variables,
          ::Types::CiConfiguration::Sast::EntityType.connection_type,
          null: true,
          description: 'List of supported variables.'
      end
      # rubocop: enable Graphql/AuthorizeTypes
    end
  end
end
