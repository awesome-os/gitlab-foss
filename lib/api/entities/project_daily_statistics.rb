# frozen_string_literal: true

module API
  module Entities
    class ProjectDailyStatistics < Grape::Entity
      expose :fetches, documentation: { type: 'Hash', desc: 'Fetch statistics of the project for the last 30 days.' } do
        expose :total_fetch_count, as: :total,
          documentation: { type: 'Integer', example: 3, desc: 'Total number of fetches in the last 30 days.' }
        expose :fetches, as: :days, using: ::API::Entities::ProjectDailyFetches, documentation: {
          type: '::API::Entities::ProjectDailyFetches', is_array: true, desc: 'Daily fetch statistics.'
        }
      end
    end
  end
end
