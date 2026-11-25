# frozen_string_literal: true

module Types
  module CiConfiguration
    module Sast
      # rubocop: disable Graphql/AuthorizeTypes
      class Type < BaseObject
        graphql_name 'SastCiConfiguration'
        description 'Represents a CI configuration of SAST'

        authorize_granular_token parent_authorizes: :read_security_configuration

        field :global,
          ::Types::CiConfiguration::Sast::EntityType.connection_type,
          null: true,
          description: 'List of global entities related to SAST configuration.'

        field :pipeline,
          ::Types::CiConfiguration::Sast::EntityType.connection_type,
          null: true,
          description: 'List of pipeline entities related to SAST configuration.'

        field :analyzers,
          ::Types::CiConfiguration::Sast::AnalyzersEntityType.connection_type,
          null: true,
          description: 'List of analyzers entities attached to SAST configuration.'
      end
      # rubocop: enable Graphql/AuthorizeTypes
    end
  end
end
