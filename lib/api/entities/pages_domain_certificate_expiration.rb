# frozen_string_literal: true

module API
  module Entities
    class PagesDomainCertificateExpiration < Grape::Entity
      expose :expired?, as: :expired,
        documentation: { type: 'Boolean', desc: 'If `true`, the SSL certificate has expired.' }
      expose :expiration,
        documentation: {
          type: 'DateTime', example: '2025-01-01T00:00:00.000Z',
          desc: 'Date and time when the SSL certificate expires.'
        }
    end
  end
end
