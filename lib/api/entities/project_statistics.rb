# frozen_string_literal: true

module API
  module Entities
    class ProjectStatistics < Grape::Entity
      expose :commit_count, documentation: { type: 'Integer', example: 37, desc: 'Number of commits in the project.' }
      expose :storage_size, documentation: { type: 'Integer', example: 1038090, desc: 'Total storage size in bytes.' }
      expose :repository_size,
        documentation: { type: 'Integer', example: 1038090, desc: 'Repository storage size in bytes.' }
      expose :wiki_size, documentation: { type: 'Integer', example: 0, desc: 'Wiki storage size in bytes.' }
      expose :lfs_objects_size,
        documentation: { type: 'Integer', example: 0, desc: 'LFS objects storage size in bytes.' }
      expose :build_artifacts_size, as: :job_artifacts_size,
        documentation: { type: 'Integer', example: 0, desc: 'Job artifacts storage size in bytes.' }
      expose :pipeline_artifacts_size,
        documentation: { type: 'Integer', example: 0, desc: 'Pipeline artifacts storage size in bytes.' }
      expose :packages_size, documentation: { type: 'Integer', example: 0, desc: 'Packages storage size in bytes.' }
      expose :snippets_size, documentation: { type: 'Integer', example: 0, desc: 'Snippets storage size in bytes.' }
      expose :uploads_size, documentation: { type: 'Integer', example: 0, desc: 'Uploads storage size in bytes.' }
      expose :container_registry_size, documentation: {
        type: 'Integer', example: 0,
        desc: 'Total container registry storage size in bytes used by all container repositories in the ' \
          'project. Updates when container images are pushed or deleted. On GitLab Self-Managed, requires ' \
          'the container registry metadata database.'
      }
    end
  end
end
