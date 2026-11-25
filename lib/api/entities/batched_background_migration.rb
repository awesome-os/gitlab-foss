# frozen_string_literal: true

module API
  module Entities
    class BatchedBackgroundMigration < Grape::Entity
      expose :id, documentation: { type: 'String', example: "1234", desc: 'ID of the batched background migration.' }
      expose :job_class_name, documentation: { type: 'String', example: "CopyColumnUsingBackgroundMigrationJob",
                                               desc: 'Name of the migration job class.' }
      expose :table_name,
        documentation: { type: 'String', example: "events", desc: 'Name of the table the migration iterates over.' }
      expose :column_name,
        documentation: { type: 'String', example: "id", desc: 'Name of the column the migration iterates over.' }
      expose :status_name, as: :status, override: true, documentation: {
        type: 'String', example: "active",
        values: ::Gitlab::Database::BackgroundMigration::BatchedMigration.valid_status.map(&:to_s),
        desc: 'Status of the migration.'
      }
      expose :progress, documentation: { type: 'Float', example: 50, desc: 'Completion percentage of the migration.' }
      expose :created_at,
        documentation: { type: 'DateTime', example: "2022-11-28T16:26:39+02:00",
                         desc: 'Timestamp when the migration was created.' }
      expose :estimated_time_remaining, documentation: {
        type: 'String', example: '1 day',
        desc: 'Estimated time until the migration completes. `null` when the migration is finished or ' \
          'no estimate is available.'
      }
    end
  end
end
