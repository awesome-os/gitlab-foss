# frozen_string_literal: true

module Gitlab
  module Database
    module Diagnostics
      module Checks
        class PendingMigrations < Base
          REGULAR = 'regular'
          POST_DEPLOYMENT = 'post_deployment'
          TYPE_ORDER = { REGULAR => 0, POST_DEPLOYMENT => 1 }.freeze

          MIGRATIONS_LIMIT = 50

          def execute
            files = migration_files
            migrations = pending_migrations(files)

            {
              migrations: migrations.first(MIGRATIONS_LIMIT),
              migrations_capped: migrations.size > MIGRATIONS_LIMIT
            }.merge(verdict(findings(files, migrations)))
          end

          private

          def findings(files, migrations)
            [
              invalid_file_names_finding(files),
              regular_finding(migrations),
              post_deployment_finding(migrations)
            ].compact
          end

          def pending_migrations(files)
            applied_versions = migration_context.get_all_versions.to_set

            # File names only, as db:migrate:status reads them: asking Rails for the
            # pending migrations loads every migration class into the process.
            migrations = files.filter_map do |file|
              version, name = version_and_name(file)
              next if version.nil? || applied_versions.include?(version.to_i)

              { version: version, name: name.camelize, type: type(file) }
            end

            # Regular first, so the limit cuts post-deployment migrations before any regular one.
            migrations.sort_by { |migration| [TYPE_ORDER.fetch(migration[:type]), migration[:version].to_i] }
          end

          def migration_context
            connection.pool.migration_context
          end

          def migration_paths
            Array(migration_context.migrations_paths)
          end

          def migration_files
            Dir[*migration_paths.map { |path| File.join(path, '**', '[0-9]*_*.rb') }]
          end

          def version_and_name(file)
            File.basename(file).scan(ActiveRecord::Migration::MigrationFilenameRegexp).first
          end

          def type(file)
            file.match?(Migrations::POST_DEPLOYMENT_PATH_REGEX) ? POST_DEPLOYMENT : REGULAR
          end

          def invalid_file_names_finding(files)
            # Rails raises IllegalMigrationNameError for such a file, in every migration task.
            names = files.reject { |file| version_and_name(file) }.map { |file| File.basename(file) }.sort
            return if names.empty?

            {
              severity: Findings::ERROR,
              code: 'migration_file_names_invalid',
              message: format(ns_(
                'DatabaseDiagnostics|%{count} file in the migration directories is not named like a ' \
                  'migration, so database migrations cannot run. Rename or remove it: %{names}',
                'DatabaseDiagnostics|%{count} files in the migration directories are not named like ' \
                  'migrations, so database migrations cannot run. Rename or remove them: %{names}',
                names.size), count: names.size, names: names.join(', '))
            }
          end

          def regular_finding(migrations)
            count = migrations.count { |migration| migration[:type] == REGULAR }
            return if count == 0

            {
              severity: Findings::ERROR,
              code: 'regular_migrations_pending',
              message: format(ns_(
                'DatabaseDiagnostics|%{count} regular migration has not run, so the database schema is behind ' \
                  'the code that GitLab runs, which can cause errors. Run the database migrations.',
                'DatabaseDiagnostics|%{count} regular migrations have not run, so the database schema is behind ' \
                  'the code that GitLab runs, which can cause errors. Run the database migrations.',
                count), count: count)
            }
          end

          def post_deployment_finding(migrations)
            return post_deployment_not_checked_finding unless post_deployment_path?

            count = migrations.count { |migration| migration[:type] == POST_DEPLOYMENT }
            return if count == 0

            {
              severity: Findings::WARNING,
              code: 'post_deployment_migrations_pending',
              message: format(ns_(
                'DatabaseDiagnostics|%{count} post-deployment migration has not run, so the upgrade is not ' \
                  'complete. This is expected for a short time after an upgrade. Until it runs, any ' \
                  'background migration it queues does not exist.',
                'DatabaseDiagnostics|%{count} post-deployment migrations have not run, so the upgrade is not ' \
                  'complete. This is expected for a short time after an upgrade. Until they run, the ' \
                  'background migrations they queue do not exist.',
                count), count: count)
            }
          end

          def post_deployment_path?
            migration_paths.any? { |path| path.to_s.match?(Migrations::POST_DEPLOYMENT_PATH_REGEX) }
          end

          def post_deployment_not_checked_finding
            # A process started with SKIP_POST_DEPLOYMENT_MIGRATIONS has no post-deployment path.
            {
              severity: Findings::WARNING,
              code: 'post_deployment_migrations_not_checked',
              message: s_('DatabaseDiagnostics|Post-deployment migrations were not checked, because this ' \
                'process has no post-deployment migration directory. This happens when it starts with ' \
                'SKIP_POST_DEPLOYMENT_MIGRATIONS set.')
            }
          end
        end
      end
    end
  end
end
