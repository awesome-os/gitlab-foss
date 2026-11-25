# frozen_string_literal: true

module API
  module Entities
    class SidekiqConcurrencyLimit < Grape::Entity
      expose :worker_class, documentation: {
        type: 'String', example: 'AuthorizedProjectsWorker', desc: 'Registered worker class name.'
      }
      expose :class_limit, documentation: {
        type: 'Integer', example: 10,
        desc: 'Explicit class limit. null when the worker has no explicit limit.'
      }
      expose :effective_limit, documentation: {
        type: 'Integer', example: 20,
        desc: 'Effective limit. Zero means unlimited. Negative values mean paused. ' \
          'null means unknown without shard context.'
      }
      expose :adaptive_limit, documentation: {
        type: 'Integer', example: 5,
        desc: 'Stored adaptive limit, or null when absent.'
      }
      expose :default_limit_requires_shard_context, documentation: {
        type: 'Boolean', example: false,
        desc: 'If `true`, the default limit is derived from shard size and cannot be reported outside a ' \
          'Sidekiq process. `false` when `sidekiq_concurrency_limit_default_calculation` is disabled, ' \
          'because the default is then `0`.'
      }
      expose :middleware_enabled, documentation: {
        type: 'Boolean', example: true, desc: 'If `true`, the concurrency limit middleware is enabled.'
      }
      expose :disabled_for_worker, documentation: {
        type: 'Boolean', example: false,
        desc: 'If `true`, the worker-specific bypass flag disables enforcement in the client and server ' \
          'middleware.'
      }
      expose :override_limit, documentation: {
        type: 'Integer', example: 20,
        desc: 'Temporary override, or null when absent.'
      }
      expose :override_ttl, documentation: {
        type: 'Integer', example: 1800,
        desc: 'Remaining override lifetime in seconds, or null when absent.'
      }
      expose :running_jobs, documentation: { type: 'Integer', example: 8, desc: 'Approximate number of running jobs.' }
      expose :deferred_jobs,
        documentation: { type: 'Integer', example: 1000, desc: 'Approximate number of deferred jobs.' }
    end
  end
end
