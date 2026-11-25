# frozen_string_literal: true

module API
  module Entities
    module SupplyChain
      class Attestation < Grape::Entity
        include ::API::Helpers::RelatedResourcesHelpers

        expose :id, documentation: { type: 'Integer', format: 'int64', example: 1, desc: 'ID of the attestation.' }
        expose :iid,
          documentation: { type: 'Integer', example: 14, desc: 'Internal ID of the attestation in the project.' }
        expose :created_at, documentation: {
          type: 'DateTime', example: '2025-09-17T02:26:10.898Z', desc: 'Date and time the attestation was created.'
        }
        expose :updated_at, documentation: {
          type: 'DateTime', example: '2025-09-17T02:26:10.898Z', desc: 'Date and time the attestation was last updated.'
        }
        expose :expire_at, documentation: {
          type: 'DateTime', example: '2025-09-17T02:26:10.898Z', desc: 'Date and time the attestation expires.'
        }

        expose :project_id, documentation: { type: 'Integer', format: 'int64', desc: 'ID of the project.' }
        expose :build_id,
          documentation: { type: 'Integer', format: 'int64',
                           desc: 'ID of the CI/CD job that produced the attestation.' }
        expose :status, documentation: {
          type: 'String', example: 'success', desc: 'Status of the attestation. One of `success` or `error`.'
        }
        expose :predicate_kind, documentation: {
          type: 'String', example: 'provenance', desc: 'Kind of predicate. One of `provenance` or `sbom`.'
        }
        expose :predicate_type, documentation: {
          type: 'String', example: 'https://slsa.dev/provenance/v1', desc: 'URI of the predicate type.'
        }
        expose :subject_digest,
          documentation: {
            type: 'String', example: '5db1fee4b5703808c48078a76768b155b421b210c0761cd6a5d223f4d99f1eaa',
            desc: 'Hex-encoded SHA-256 hash of the artifact.'
          }
        expose :signing_method,
          documentation: {
            type: 'String', example: 'local_ca', values: %w[sigstore local_ca],
            desc: 'Method used to sign the attestation. If `ATTEST_METHOD` is not set, defaults to `local_ca`, ' \
              'except for public projects on GitLab.com, which default to `sigstore`.'
          }

        expose :download_url,
          documentation: { type: 'String', desc: 'URL to download the attestation bundle.' } do |attestation|
          expose_url(api_v4_projects_attestations_download_path(id: attestation.project_id, attestation_iid:
                                                                attestation.iid))
        end
      end
    end
  end
end
