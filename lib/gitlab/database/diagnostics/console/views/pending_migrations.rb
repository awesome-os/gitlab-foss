# frozen_string_literal: true

module Gitlab
  module Database
    module Diagnostics
      module Console
        module Views
          class PendingMigrations < Base
            MIGRATION_HEADERS = %w[VERSION NAME TYPE].freeze
            CAPPED = "Only the first #{Checks::PendingMigrations::MIGRATIONS_LIMIT} migrations are listed. " \
              'The findings count every migration.'.freeze

            TYPE_LABELS = {
              Checks::PendingMigrations::REGULAR => 'regular',
              Checks::PendingMigrations::POST_DEPLOYMENT => 'post-deployment'
            }.freeze

            def self.title
              'Pending migrations'
            end

            private

            def print_database(database_name, payload)
              pending_migrations = payload[:pending_migrations] || {}

              print_status(database_name, pending_migrations)
              print_findings(pending_migrations[:findings] || [])
              print_migrations(pending_migrations[:migrations] || [], pending_migrations[:migrations_capped])
            end

            def print_migrations(migrations, capped)
              return if migrations.empty?

              printer.table(MIGRATION_HEADERS, migrations.map { |migration| migration_row(migration) })
              printer.detail(CAPPED) if capped
            end

            def migration_row(migration)
              [migration[:version], migration[:name], TYPE_LABELS.fetch(migration[:type])]
            end
          end
        end
      end
    end
  end
end
