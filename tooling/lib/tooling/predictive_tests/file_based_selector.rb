# frozen_string_literal: true

require 'date'
require 'yaml'

require_relative '../domains'
require_relative '../find_tests'

module Tooling
  module PredictiveTests
    # Picks the rspec files that loaded any of the changed source files, using the ClickHouse coverage map.
    # Returns no specs and a reason when the change can't be judged from the map, so the caller runs the full suite.
    class FileBasedSelector
      Result = Struct.new(:specs, :full_suite_reason, keyword_init: true)

      # Spec helpers, shared examples and factories have map rows too. Frontend fixtures run in their own job.
      SOURCE_FILE_REGEX = %r{
        \A(?:#{Tooling::Domains::PATH_PREFIX}(?:ee/)?(?:app|lib)|rubocop|tooling|scripts|danger)/.+\.rb\z|
        \A#{Tooling::Domains::PATH_PREFIX}(?:ee/)?spec/(?!frontend/fixtures/).+(?<!_spec)\.rb\z
      }x
      SPEC_FILE_REGEX = %r{\A#{Tooling::Domains::PATH_PREFIX}(?:ee/)?spec/.+_spec\.rb\z}
      # System specs also depend on frontend code, which the map can't see.
      SYSTEM_SPEC_REGEX = %r{\A#{Tooling::Domains::PATH_PREFIX}(?:ee/)?spec/features/}
      # Frontend code, jest specs and docs. The Vue 3 migration specs read two kinds of these files, so keep them.
      IGNORED_FILE_REGEX = %r{
        \A(?!.*(?:vue3_migration\.yml|/pages/.+/index\.js)\z)
        (?:.*\.(?:vue|js|mjs|ts|scss|css|md|snap)\z|(?:ee/)?app/assets/)
      }x
      # Regenerated from code and checked by their own CI jobs, not rspec.
      GENERATED_FILES = %w[
        locale/gitlab.pot
        public/-/graphql/introspection_result.json
        public/-/graphql/introspection_result_no_deprecated.json
        doc/api/openapi/openapi_v3.yaml
        config/routing/gitlab_routes.json
      ].freeze
      # Lint settings read by linters, not rspec.
      LINT_FILE_REGEX = %r{
        \A(?:\.rubocop_todo/.+\.yml|scripts/lint/keela_(?:baseline|excluded)\.yml|
        \.haml-lint\.yml|\.markdownlint-cli2\.yaml|gems/config/rubocop\.yml)\z
      }x
      # Run only by the frontend fixtures job or by each gem's own pipeline.
      OWN_JOB_FILE_REGEX = %r{
        \A(?:#{Tooling::Domains::PATH_PREFIX}(?:ee/)?spec/frontend/fixtures/.+\.rb|
        (?:vendor/)?gems/[^/]+/(?:Gemfile\.lock|\.gitignore|\.rspec|\.rubocop\.yml))\z
      }x
      SKIPPED_FILE_REGEX = Regexp.union(IGNORED_FILE_REGEX, LINT_FILE_REGEX, OWN_JOB_FILE_REGEX)
      FEATURE_FLAG_FILE_REGEX = %r{\A(?:ee/)?config/feature_flags/.+\.yml\z}
      # Code reads these by name. rspec_order_todo.yml changes spec order instead.
      NAMED_DATA_FILE_REGEX = %r{
        \A(?:ee/)?(?:app/validators/json_schemas/.+\.json|spec/fixtures/api/schemas/.+\.json|
        spec/support/(?!rspec_order_todo\.yml\z).+\.ya?ml)\z
      }x
      # Loaded together by glob, so specs reading every definition cover them.
      DEFINITION_FILE_REGEX = %r{\A(?:ee/)?config/(?:events|metrics)/.+\.(?:yml|json)\z}
      # These mention a file name without reading the file.
      NAME_MENTION_ONLY_REGEX = %r{\A(?:\.gitlab/|\.ai/|doc/|doc-locale/|tests\.yml\z)}
      # Work item type definitions load once per process and stay in memory.
      # The coverage map links them to only some of the specs that read them.
      CACHED_DATA_FILE_REGEX = %r{
        \A#{Tooling::Domains::PATH_PREFIX}(?:ee/)?app/models/work_items/types_framework/system_defined/definitions/
      }x
      # ClickHouse rejects queries over 256 KiB, so long path lists are queried in batches.
      BATCH_SIZE = 1_000
      # Capture runs about every 2 hours, so 6 hours without a new row means it has stalled.
      MAX_MAP_AGE_SECONDS = 6 * 60 * 60
      # Past this many specs changed since the last capture, the map is too far behind to trust.
      MAX_RECENT_SPECS = 500

      # `recent_changed_files` are the files changed on master since the map's last capture, or nil when unknown.
      # `flag_users` finds files naming a flag or data file. Nil on failure.
      # `definition_specs` finds specs reading every event or metric definition. Nil on failure.
      def initialize( # rubocop:disable Metrics/ParameterLists -- the last two are swapped out in specs
        changed_files:, clickhouse_client:, project_path:, flag_users:, definition_specs:,
        recent_changed_files: [], added_files: [],
        file_exists: File.method(:exist?), static_specs: ->(files) { Tooling::FindTests.new(files).execute }
      )
        @changed_files = changed_files
        @added_files = added_files
        @flag_users = flag_users
        @find_definition_specs = definition_specs
        @recent_changed_files = recent_changed_files
        @clickhouse_client = clickhouse_client
        @project_path = project_path
        @file_exists = file_exists
        @static_specs = static_specs
      end

      def execute
        relevant = (judge_data_files(judge_feature_flags(changed_files)) - GENERATED_FILES)
          .reject { |f| SKIPPED_FILE_REGEX.match?(f) }
        sources, others = relevant.partition { |file| SOURCE_FILE_REGEX.match?(file) }
        own_specs, others = others.partition { |file| SPEC_FILE_REGEX.match?(file) }
        others += sources.grep(CACHED_DATA_FILE_REGEX)

        return full_suite("files the map can't judge: #{others.sort.join(', ')}") if others.any?

        return full_suite("can't tell what changed since the last capture") if sources.any? && recent_changed_files.nil?

        age = map_age_seconds if sources.any?
        return full_suite("map is stale: newest capture is #{age / 3600} hours old") if age && age > MAX_MAP_AGE_SECONDS

        specs_by_source = specs_for(sources)
        unmapped = sources - specs_by_source.keys - new_files_with_own_spec(sources, own_specs)
        return full_suite("no map rows for: #{unmapped.sort.join(', ')}") if unmapped.any?

        recent_specs = recent_changes(sources)
        if recent_specs.size > MAX_RECENT_SPECS
          return full_suite("#{recent_specs.size} specs changed since the last capture")
        end

        # Specs changed on master after the capture have no map rows yet.
        # tests.yml adds specs reading data built at boot, unseen by the map.
        specs = (specs_by_source.values.flatten + own_specs + recent_specs + static_specs.call(sources))
          .grep_v(SYSTEM_SPEC_REGEX)
        Result.new(specs: specs.uniq.select { |spec| @file_exists.call(spec) }.sort, full_suite_reason: nil)
      end

      private

      attr_reader :changed_files, :added_files, :flag_users, :clickhouse_client, :project_path, :recent_changed_files,
        :static_specs

      # The map holds rows for code files, so judge flags through them.
      def judge_feature_flags(files)
        flags, rest = files.partition { |file| FEATURE_FLAG_FILE_REGEX.match?(file) }
        changes_ruby = rest.any? { |file| SOURCE_FILE_REGEX.match?(file) }
        # A flag moved to another stage is neither new nor deleted.
        moved = flags.map { |flag| File.basename(flag) }.tally.select { |_, count| count > 1 }.keys

        (rest + flags.flat_map do |flag|
          stand_ins_for(flag, changes_ruby && moved.none?(File.basename(flag)))
        end).uniq
      end

      def stand_ins_for(flag, changes_ruby)
        # Only the MR's Ruby uses a new flag, so its specs cover it.
        return [] if changes_ruby && added_files.include?(flag)

        # Docs and frontend hits are dropped later, so they can't stand in for the flag.
        users = flag_users.call(File.basename(flag, '.yml'))&.reject do |file|
          FEATURE_FLAG_FILE_REGEX.match?(file) || SKIPPED_FILE_REGEX.match?(file) || GENERATED_FILES.include?(file)
        end
        return users if users&.any?
        # The MR's own Ruby removed a deleted flag's last uses.
        return [] if users && changes_ruby && !@file_exists.call(flag)

        # An empty search usually means a dynamic name, like `geo_<type>_replication`.
        [flag]
      end

      # Data files lack map rows, so judge them by their readers.
      def judge_data_files(files)
        files.flat_map do |file|
          if DEFINITION_FILE_REGEX.match?(file)
            specs = definition_specs
            readers = definition_readers(file)
            specs && readers ? specs + readers : [file]
          elsif NAMED_DATA_FILE_REGEX.match?(file)
            readers = readers_of(file)
            readers&.any? ? readers : [file]
          else
            [file]
          end
        end.uniq
      end

      def definition_specs
        return @definition_specs if defined?(@definition_specs)

        @definition_specs = @find_definition_specs.call
      end

      # File names often differ from code, so search the names inside.
      def definition_readers(file)
        names = definition_names(file)
        readers = names&.map { |name| readers_of(file, name) }
        readers.flatten.uniq if readers&.none?(&:nil?)
      end

      def definition_names(file)
        return unless @file_exists.call(file)

        data = YAML.safe_load_file(file, permitted_classes: [Date])
        return [File.basename(file, '.*')] unless data.is_a?(Hash)

        events = Array(data['events']).filter_map { |event| event['name'] if event.is_a?(Hash) }
        hll_events = Array(data.dig('options', 'events')).grep(String)
        names = [File.basename(file, '.*'), data['action'], data['key_path'], data['instrumentation_class']]
        [*names, *events, *hll_events].compact.uniq
      rescue StandardError
        nil
      end

      # Definition hits are covered. Non-Ruby readers stay and force the full suite.
      def readers_of(file, name = File.basename(file, '.*'))
        flag_users.call(name)&.reject do |hit|
          hit == file || DEFINITION_FILE_REGEX.match?(hit) || NAME_MENTION_ONLY_REGEX.match?(hit) ||
            SKIPPED_FILE_REGEX.match?(hit) || GENERATED_FILES.include?(hit)
        end
      end

      # New files lack map rows, so specs matching folder and name cover them.
      def new_files_with_own_spec(sources, own_specs)
        spec_keys = own_specs.map { |spec| spec.delete_suffix('_spec.rb').split('/').last(2) }
        (sources & added_files).select { |file| spec_keys.include?(file.delete_suffix('.rb').split('/').last(2)) }
      end

      def recent_changes(sources)
        return [] if sources.empty?

        recent_changed_files.grep(SPEC_FILE_REGEX)
      end

      def full_suite(reason)
        Result.new(specs: [], full_suite_reason: reason)
      end

      def map_age_seconds
        sql = <<~SQL
          SELECT dateDiff('second', max(timestamp), now()) AS age FROM code_coverage.test_coverage_per_file
          WHERE ci_project_path = '#{escape(project_path)}' AND test_file NOT LIKE 'qa/%'
        SQL

        clickhouse_client.query(sql, format: 'JSONEachRow').dig(0, 'age').to_i
      end

      def specs_for(sources)
        sources.each_slice(BATCH_SIZE).each_with_object(Hash.new { |hash, key| hash[key] = [] }) do |batch, memo|
          query(batch).each { |row| memo[row['source_file']] << row['test_file'] }
        end
      end

      def query(sources)
        list = sources.map { |file| "'#{escape(file)}'" }.join(', ')
        sql = <<~SQL
          SELECT DISTINCT source_file, test_file FROM code_coverage.test_files_by_source_file FINAL
          WHERE ci_project_path = '#{escape(project_path)}'
            AND source_file IN (#{list})
            AND test_file NOT LIKE 'qa/%'
            AND test_file LIKE '%_spec.rb'
        SQL

        clickhouse_client.query(sql, format: 'JSONEachRow')
      end

      def escape(value)
        value.to_s.gsub("'", "''")
      end
    end
  end
end
