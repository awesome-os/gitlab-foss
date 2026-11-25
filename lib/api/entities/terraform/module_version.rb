# frozen_string_literal: true

module API
  module Entities
    module Terraform
      class ModuleVersion < Grape::Entity
        expose :name
        expose :provider
        expose :providers, documentation: { type: 'String', is_array: true }
        expose :root, documentation: { type: 'Hash' }
        expose :source
        expose :submodules, documentation: { type: 'String', is_array: true }
        expose :version
        expose :versions, documentation: { type: 'String', is_array: true }
      end
    end
  end
end
