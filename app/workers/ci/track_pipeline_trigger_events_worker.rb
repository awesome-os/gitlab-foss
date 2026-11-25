# frozen_string_literal: true

module Ci
  class TrackPipelineTriggerEventsWorker
    include Gitlab::EventStore::Subscriber
    include Gitlab::InternalEventsTracking

    data_consistency :sticky
    feature_category :continuous_integration
    urgency :low
    defer_on_database_health_signal :gitlab_ci, [:p_ci_builds, :ci_pipelines], 1.minute

    idempotent!

    def handle_event(event)
      pipeline = Ci::Pipeline.in_partition(event.data[:partition_id]).find_by_id(event.data[:pipeline_id])
      return unless pipeline

      pipeline_user = pipeline.user
      user_type = pipeline_user&.bot? ? 'bot' : 'human'

      track_internal_event(
        'ci_pipeline_triggered',
        user: pipeline_user,
        project: pipeline.project,
        additional_properties: { user_type: user_type }
      )

      Gitlab::InternalEvents.with_batched_redis_writes do
        pipeline.builds.find_each do |build|
          # On Ci::PipelineCreatedEvent every build was seeded with the pipeline user
          # (Gitlab::Ci::Pipeline::Seed::Build#pipeline_attributes), so reusing that record is safe;
          # a build with another user falls back to its own record.
          build_user = build.user_id == pipeline.user_id ? pipeline_user : build.user

          track_internal_event(
            'ci_build_triggered',
            user: build_user,
            project: pipeline.project,
            additional_properties: { user_type: user_type }
          )
        end
      end
    end
  end
end
