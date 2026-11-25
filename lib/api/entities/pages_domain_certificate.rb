# frozen_string_literal: true

module API
  module Entities
    class PagesDomainCertificate < Grape::Entity
      expose :subject, documentation: {
        type: 'String', desc: 'Subject of the SSL certificate, usually with information about the domain.'
      }
      expose :expired?, as: :expired,
        documentation: { type: 'Boolean', desc: 'If `true`, the SSL certificate has expired.' }
      expose :certificate, documentation: { type: 'String', desc: 'Full SSL certificate in PEM format.' }
      expose :certificate_text, documentation: {
        type: 'String',
        desc: 'Human-readable text of the SSL certificate, with details such as the issuer, validity period, ' \
          'and subject.'
      }
    end
  end
end
