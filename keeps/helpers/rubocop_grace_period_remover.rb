# frozen_string_literal: true

require 'erb'
require 'yaml'
require_relative 'gitlab_api_helper'
require_relative '../../rubocop/formatter/graceful_formatter'

module Keeps
  module Helpers
    # Removes the RuboCop grace period line (`Details: grace period`) from `.rubocop_todo` YAML files, but only once
    # the grace period is at least MIN_AGE_DAYS old.
    #
    # The age is the line's blame commit date, which for a commit merged without squash is before the merge.
    #
    # See https://docs.gitlab.com/development/rubocop_development_guide/#cop-grace-period.
    class RubocopGracePeriodRemover
      TODO_DIR_PATTERN = ".rubocop_todo/*.yml"
      KEY_VALUE = ::RuboCop::Formatter::GracefulFormatter.grace_period_key_value.freeze
      MIN_AGE_DAYS = 7
      PATTERN = /^[ \t]*#{Regexp.escape(KEY_VALUE)}\n/
      BLAME_URL = 'https://gitlab.com/api/v4/projects/gitlab-org%%2Fgitlab/repository/files/%<path>s/blame' \
        '?ref=%<ref>s&range[start]=%<line>d&range[end]=%<line>d'

      def remove_overdue
        files_with_grace_period.each do |file|
          next unless overdue?(file)

          remove_grace_period(file)
        end
      end

      private

      # Use `git grep` to find the few files containing a grace period in a single pass instead of scanning every todo
      # file in Ruby.
      def files_with_grace_period
        output = ::Gitlab::Housekeeper::Shell.execute(
          'git', 'grep', '--files-with-matches', '--fixed-strings', KEY_VALUE, '--', TODO_DIR_PATTERN
        )

        output.each_line.map(&:chomp).reject(&:empty?)
      rescue ::Gitlab::Housekeeper::Shell::Error => e
        # `git grep` exits non-zero when there are no matches, which is expected.
        warn "[RubocopGracePeriodRemover] git grep found no files with a grace period: #{e.message}"
        []
      end

      def remove_grace_period(file_path)
        content = File.read(file_path).gsub(PATTERN, '')

        # RuboCop rejects a cop with no settings, and a cop without exclusions needs no todo file.
        if YAML.safe_load(content).values.all?(&:nil?)
          File.delete(file_path)
        else
          File.write(file_path, content)
        end
      end

      def overdue?(file_path)
        revision = head_revision
        line = committed_grace_period_line(file_path, revision)
        return false unless line

        added_at = grace_period_added_at(file_path, line, revision)
        return false unless added_at

        added_at <= MIN_AGE_DAYS.days.ago
      end

      # HEAD, not the working tree, because the todo files were just regenerated.
      def committed_grace_period_line(file_path, revision)
        output = ::Gitlab::Housekeeper::Shell.execute(
          'git', 'grep', '--line-number', '--fixed-strings', KEY_VALUE, revision, '--', file_path
        )

        # Each line is `<revision>:<path>:<line number>:<text>`.
        output[/\A[^:]+:[^:]+:(\d+):/, 1]&.to_i
      rescue ::Gitlab::Housekeeper::Shell::Error
        nil
      end

      def grace_period_added_at(file_path, line, revision)
        url = format(BLAME_URL, path: ERB::Util.url_encode(file_path), ref: revision, line: line)
        blame = api_helper.get(url)[:results]

        unless blame.is_a?(Array) && blame.any?
          warn "[RubocopGracePeriodRemover] blame of #{file_path}:#{line} failed: #{blame.inspect}"
          return
        end

        Time.parse(blame.first.dig('commit', 'committed_date'))
      rescue StandardError => e
        warn "[RubocopGracePeriodRemover] blame of #{file_path}:#{line} failed: #{e.message}"
        nil
      end

      def head_revision
        @head_revision ||= ::Gitlab::Housekeeper::Shell.execute('git', 'rev-parse', 'HEAD').strip
      end

      def api_helper
        @api_helper ||= GitlabApiHelper.new(token: ENV['HOUSEKEEPER_GITLAB_API_TOKEN'])
      end
    end
  end
end
