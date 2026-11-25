# frozen_string_literal: true

module API
  module Entities
    # Serializes a Licensee::License
    class License < Entities::LicenseBasic
      expose :popular?, as: :popular,
        documentation: { type: 'Boolean', desc: 'If `true`, the license is a popular license.' }

      expose :description,
        documentation: { type: 'String', example: 'A simple license', desc: 'Description of the license.' } do |license|
        license.meta['description']
      end

      expose :conditions,
        documentation: {
          type: 'String', is_array: true, example: ['include-copyright'], desc: 'Conditions of the license.'
        } do |license|
        license.meta['conditions']
      end

      expose :permissions,
        documentation: {
          type: 'String', is_array: true, example: ['commercial-use'], desc: 'Permissions the license grants.'
        } do |license|
        license.meta['permissions']
      end

      expose :limitations,
        documentation: { type: 'String', is_array: true, example: ['liability'],
                         desc: 'Limitations of the license.' } do |license|
        license.meta['limitations']
      end

      expose :content,
        documentation: { type: 'String', example: 'GNU GENERAL PUBLIC LICENSE', desc: 'Content of the template.' }
    end
  end
end
