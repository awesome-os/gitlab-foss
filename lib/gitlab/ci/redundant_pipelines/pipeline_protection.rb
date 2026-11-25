# frozen_string_literal: true

module Gitlab
  module Ci
    module RedundantPipelines
      class PipelineProtection
        def initialize(build)
          @build = build
        end

        def protect
          cache.protect(key) if applies?

          self
        end

        def persist
          return unless applies?
          return if protected_in_database?

          ::Ci::RedundantPipelines::ProtectPipelineWorker.perform_async(pipeline_id, partition_id)
        end

        private

        attr_reader :build

        delegate :project_id, :ref, :pipeline_id, :partition_id, to: :build, private: true

        def applies?
          ::Feature.enabled?(:ci_redundant_pipeline_candidates_cache, ::Project.actor_from_id(project_id)) &&
            !build.interruptible
        end

        def protected_in_database?
          ::Gitlab::Database::LoadBalancing::SessionMap.use_replica_if_available do
            build.pipeline.interruptible_protected?
          end
        end

        def cache
          CandidateCache.for(project_id: project_id, ref: ref)
        end

        def key
          PipelineKey.new(pipeline_id, partition_id)
        end
      end
    end
  end
end
