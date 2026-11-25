# frozen_string_literal: true

module API
  class UsageDataTrack < UsageData
    before { authenticate_non_get! }

    allow_access_with_scope :ai_workflows

    helpers ::API::Helpers::UsageDataHelpers

    namespace 'usage_data' do
      resource :track_event do
        desc 'Track an internal GitLab event' do
          detail 'Tracks a GitLab internal event. This action increments Service Ping counters in Redis and is ' \
            'optionally sent to Snowplow. To track multiple events in one request, send an array of events to the ' \
            '`/track_events` endpoint. The `/track_event` and `/track_events` endpoints share a rate limit of 200 ' \
            'events per minute for each user. Each event counts toward the limit, so a `/track_events` request ' \
            'counts one unit for each event in the array. The rate limit is behind a feature flag named ' \
            '`rate_limit_track_internal_events`. Disabled by default. Requires a personal access token with the ' \
            '`api` or `ai_workflows` scope.'
          success code: 200
          failure [
            { code: 401, message: 'Unauthorized' },
            { code: 404, message: 'Not found' },
            { code: 429, message: 'Too many requests' }
          ]
          tags %w[usage_data]
        end

        params do
          use :event_params
        end

        route_setting :authorization, permissions: :track_internal_event, boundary_type: :instance
        post urgency: :low do
          check_track_internal_events_rate_limit!

          process_event(params)

          status :ok
        end
      end
    end
  end
end
