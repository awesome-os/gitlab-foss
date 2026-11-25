# frozen_string_literal: true

module API
  module Entities
    class Metadata < Grape::Entity
      expose :version, documentation: { type: 'String', example: '15.2-pre', desc: 'Version of the GitLab instance.' }
      expose :revision,
        documentation: { type: 'String', example: 'c401a659d0c', desc: 'Revision of the GitLab instance.' }
      expose :kas,
        documentation: { type: 'Hash', desc: 'Metadata about the GitLab agent server for Kubernetes (KAS).' } do
        expose :enabled, documentation: { type: 'Boolean', desc: 'If `true`, KAS is enabled.' }
        expose :externalUrl,
          documentation: {
            type: 'String', example: 'grpc://gitlab.example.com:8150',
            desc: 'URL the agents use to communicate with KAS. `null` if `kas.enabled` is `false`.'
          }
        expose :externalK8sProxyUrl,
          documentation: {
            type: 'String', example: 'https://gitlab.example.com:8150/k8s-proxy',
            desc: 'URL the Kubernetes tooling uses to communicate with the KAS Kubernetes API proxy. ' \
              '`null` if `kas.enabled` is `false`.'
          }
        expose :version,
          documentation: {
            type: 'String', example: '15.0.0',
            desc: 'Version of KAS. `null` if `kas.enabled` is `false` or the instance failed to fetch server ' \
              'information from KAS.'
          }
      end
      expose :enterprise,
        documentation: { type: 'Boolean', desc: 'If `true`, the instance runs GitLab Enterprise Edition.' }
      expose :plan,
        documentation: {
          type: 'String', example: 'ultimate', x: { nullable: true },
          desc: 'Plan of the license the instance runs under. An active ' \
            'trial license reports its plan the same way as a paid license. `free` on an instance with no ' \
            'license or with an expired trial. An expired paid license still reports its plan, because its ' \
            'licensed features remain available. `null` where subscriptions are scoped for each namespace ' \
            'rather than for an instance, such as GitLab.com.'
        }
    end
  end
end
