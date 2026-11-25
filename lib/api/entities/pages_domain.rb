# frozen_string_literal: true

module API
  module Entities
    class PagesDomain < Grape::Entity
      expose :domain, documentation: { type: 'String', desc: 'Custom domain name of the Pages site.' }
      expose :url, documentation: { type: 'String', desc: 'Full URL of the Pages site, including the protocol.' }
      expose :verified?, as: :verified,
        documentation: { type: 'Boolean', desc: 'If `true`, the domain is verified.' }
      expose :verification_code, as: :verification_code,
        documentation: { type: 'String', desc: 'Unique record used to verify domain ownership.' }
      expose :enabled_until, documentation: {
        type: 'DateTime',
        desc: 'Date until which the domain is enabled. Updated periodically as the domain is reverified.'
      }
      expose :auto_ssl_enabled, documentation: {
        type: 'Boolean',
        desc: "If `true`, automatic generation of SSL certificates with Let's Encrypt is enabled for the domain."
      }

      expose :certificate,
        if: ->(pages_domain, _) { pages_domain.certificate? },
        using: Entities::PagesDomainCertificate,
        documentation: {
          type: '::API::Entities::PagesDomainCertificate',
          desc: 'SSL certificate of the domain. Returned only if the domain has a certificate.'
        } do |pages_domain|
        pages_domain
      end
    end
  end
end
