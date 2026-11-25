# frozen_string_literal: true

module API
  module Admin
    class Sidekiq < ::API::Base
      before { authenticated_as_admin! }

      feature_category :sidekiq

      LIMIT_MANAGER = ::Gitlab::SidekiqMiddleware::ConcurrencyLimit::LimitManager

      QUEUE_METADATA_DESCRIPTIONS = {
        'user' => 'Username of the user who scheduled the jobs.',
        'project' => 'Full path of the project where the jobs were scheduled from.',
        'root_namespace' => 'Root namespace of the project.',
        'subscription_plan' => 'Subscription plan of the root namespace. GitLab.com only.',
        'caller_id' => 'Endpoint or background job that scheduled the job, for example ' \
          '`ProjectsController#create`, `/api/:version/projects/:id`, or `PostReceive`.',
        'feature_category' => 'Feature category of the background job, for example `team_planning` or ' \
          '`code_review`.',
        'client_type' => 'Kind of client whose request scheduled the jobs, for example `browser`, `ide`, or ' \
          '`mobile`.',
        'client_name' => 'Client whose request scheduled the jobs, for example `vscode` or `gitlab-mobile-ios`.',
        'client_version' => 'Release of the client whose request scheduled the jobs, for example `6.21.0` or ' \
          '`1.2.0`.',
        'worker_class' => 'Class of the background job worker, for example `PostReceive` or `MergeWorker`.'
      }.freeze

      helpers ::API::Helpers::SidekiqConcurrencyLimitsHelpers

      namespace 'admin' do
        namespace 'sidekiq' do
          params do
            requires :worker_class, type: String, regexp: /\A[A-Z]\w*(?:::[A-Z]\w*)*\z/,
              desc: 'Registered Sidekiq worker class name.'
          end
          namespace 'concurrency_limits/:worker_class' do
            desc 'Get a Sidekiq worker concurrency limit' do
              detail 'Returns concurrency limits, override expiry and job counts. Namespaced worker class names keep ' \
                'the `::` separator in the path. This feature was introduced in GitLab 19.6.'
              success Entities::SidekiqConcurrencyLimit
              failure [{ code: 401, message: 'Unauthorized' },
                { code: 403, message: 'Administrator access required' },
                { code: 404, message: 'Worker not found' }]
              tags ['sidekiq']
            end
            route_setting :authorization, permissions: :read_sidekiq_concurrency_limit, boundary_type: :instance,
              assignable_when: [:admin]
            get do
              worker = concurrency_limit_worker
              present concurrency_limit_status(worker, concurrency_limit_service(worker)),
                with: Entities::SidekiqConcurrencyLimit
            end

            desc 'Update a Sidekiq worker concurrency limit override' do
              detail 'Sets or replaces a temporary concurrency override. ' \
                'Overrides adaptive throttling until the TTL expires or the override is deleted. ' \
                'Replacing an override restarts its TTL. Workers without a limit can receive a temporary cap. ' \
                'A positive override takes precedence over adaptive throttling and the class default. Pausing ' \
                'takes precedence over an override. Disabled concurrency middleware ignores overrides. When an ' \
                'override expires or is cleared, the stored adaptive limit resumes if it remains valid. Otherwise, ' \
                "the worker's runtime default applies. Lowering a limit does not terminate running jobs. The " \
                'override is rejected if the worker is paused, the `sidekiq_concurrency_limit_middleware` feature ' \
                "flag is disabled, the worker's `disable_sidekiq_concurrency_limit_middleware_<WorkerClass>` " \
                'bypass flag is enabled, or the worker is `ConcurrencyLimit::ResumeWorker`, which resumes deferred ' \
                'jobs and cannot be limited. This feature was introduced in GitLab 19.6.'
              success Entities::SidekiqConcurrencyLimit
              failure [{ code: 400, message: 'Invalid override' },
                { code: 401, message: 'Unauthorized' },
                { code: 403, message: 'Administrator access required' },
                { code: 404, message: 'Worker not found' }]
              tags ['sidekiq']
            end
            params do
              requires :limit, type: Integer, desc: 'Positive concurrency limit.'
              optional :ttl, type: Integer, default: LIMIT_MANAGER::TTL.to_i,
                values: 1..LIMIT_MANAGER::OVERRIDE_MAX_TTL.to_i, desc: 'Override lifetime in seconds.'
            end
            route_setting :authorization, permissions: :update_sidekiq_concurrency_limit_override,
              boundary_type: :instance, assignable_when: [:admin]
            put do
              worker = concurrency_limit_worker
              service = concurrency_limit_service(worker)
              previous = service.override_status
              service.set_override_limit!(params[:limit], ttl: params[:ttl])
              log_concurrency_limit_override(worker, 'set', previous, service.override_status)
              present concurrency_limit_status(worker, service), with: Entities::SidekiqConcurrencyLimit
            rescue LIMIT_MANAGER::InvalidOverrideError => e
              bad_request!(e.message)
            end

            desc 'Delete a Sidekiq worker concurrency limit override' do
              detail 'Clears the temporary override and returns the updated concurrency-limit status. ' \
                'Restores the adaptive limit if present, otherwise the worker default. ' \
                'This feature was introduced in GitLab 19.6.'
              success Entities::SidekiqConcurrencyLimit
              failure [{ code: 401, message: 'Unauthorized' },
                { code: 403, message: 'Administrator access required' },
                { code: 404, message: 'Worker not found' }]
              tags ['sidekiq']
            end
            route_setting :authorization, permissions: :delete_sidekiq_concurrency_limit_override,
              boundary_type: :instance, assignable_when: [:admin]
            delete do
              worker = concurrency_limit_worker
              service = concurrency_limit_service(worker)
              previous = service.override_status
              service.clear_override_limit!
              log_concurrency_limit_override(worker, 'reset', previous, service.override_status)
              present concurrency_limit_status(worker, service), with: Entities::SidekiqConcurrencyLimit
            end
          end

          namespace 'queues' do
            desc 'Delete jobs from a Sidekiq queue' do
              detail 'Deletes jobs from a Sidekiq queue that match the specified metadata. The response has three ' \
                'fields: `deleted_jobs` is the number of jobs deleted by the request, `queue_size` is the remaining ' \
                'size of the queue after the request, and `completed` is whether the request processed the entire ' \
                'queue in time. If `completed` is `false`, retrying with the same parameters can delete more jobs, ' \
                'including jobs added after the first request. Only available to administrators.'
              tags ['sidekiq']
            end
            params do
              requires :queue_name, type: String, desc: 'Name of the queue to delete jobs from.'

              Gitlab::SidekiqQueue::ALLOWED_KEYS.each do |key|
                optional key, type: String, desc: QUEUE_METADATA_DESCRIPTIONS.fetch(key, 'Metadata key to match'),
                  allow_blank: false
              end

              at_least_one_of(*Gitlab::SidekiqQueue::ALLOWED_KEYS)
            end
            route_setting :authorization, permissions: :drop_sidekiq_job, boundary_type: :instance,
              assignable_when: [:admin]
            delete ':queue_name' do
              result =
                Gitlab::SidekiqQueue
                  .new(params[:queue_name])
                  .drop_jobs!(declared_params, timeout: 30)

              present result
            rescue Gitlab::SidekiqQueue::NoMetadataError
              render_api_error!("Invalid metadata: #{declared_params}", 400)
            rescue Gitlab::SidekiqQueue::InvalidQueueError
              not_found!(params[:queue_name])
            end
          end
        end
      end
    end
  end
end
