# frozen_string_literal: true

module API
  module Entities
    class ProjectIdentity < Grape::Entity
      expose :id, documentation: { type: 'Integer', format: 'int64', example: 1, desc: 'ID of the project.' }
      expose :description, documentation: { type: 'String', example: 'desc', desc: 'Description of the project.' }
      expose :name, documentation: { type: 'String', example: 'project1', desc: 'Name of the project.' }
      expose :name_with_namespace,
        documentation: { type: 'String', example: 'John Doe / project1',
                         desc: 'Name of the project with its namespace.' }
      expose :path, documentation: { type: 'String', example: 'project1', desc: 'Path of the project.' }
      expose :path_with_namespace,
        documentation: { type: 'String', example: 'namespace1/project1',
                         desc: 'Path of the project with its namespace.' }
      expose :created_at,
        documentation: { type: 'DateTime', example: '2020-05-07T04:27:17.016Z',
                         desc: 'Date and time when the project was created.' }
    end
  end
end
