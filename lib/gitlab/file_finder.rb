# frozen_string_literal: true

# This class finds files in a repository by name and content
# the result is joined and sorted by file name
module Gitlab
  class FileFinder
    MAX_MATCH_BYTES = 64.kilobytes
    # Gitaly rejects requests with more or longer pathspecs.
    MAX_PATHSPECS = 32
    MAX_PATHSPEC_BYTES = 1000
    # Without "glob" magic, "*" matches "/" too, like ".*?" in the filters' regexes.
    PATHSPEC_PATTERNS = { filename: '*%s', path: '*%s*', extension: '*.%s' }.freeze

    attr_reader :project, :ref

    delegate :repository, to: :project

    def initialize(project, ref)
      @project = project
      @ref = ref
    end

    def find(query, content_match_cutoff: nil)
      query = Gitlab::Search::Query.new(query, encode_binary: true) do
        filter :filename, matcher: ->(filter, blob) do
          ::Gitlab::UntrustedRegexp.new("(?i)#{filter[:regex_value]}$").match?(blob.binary_path)
        end

        filter :path, matcher: ->(filter, blob) do
          ::Gitlab::UntrustedRegexp.new("(?i)#{filter[:regex_value]}").match?(blob.binary_path)
        end

        filter :extension, matcher: ->(filter, blob) do
          ::Gitlab::UntrustedRegexp.new("(?i)\\.#{filter[:regex_value]}$").match?(blob.binary_path)
        end
      end

      content_options =
        if Feature.enabled?(:limit_basic_blob_search, project)
          limited_content_options(query, content_match_cutoff)
        else
          { limit: (content_match_cutoff unless query.filters.any?) }
        end

      files = find_by_path(query.term) + find_by_content(query.term, content_options)

      files = query.filter_results(files) if query.filters.any?

      files
    rescue Gitlab::Git::Repository::NoRepository
      []
    end

    private

    # The filters still run on the results, so the pathspecs only have to narrow the search down to a superset.
    def limited_content_options(query, content_match_cutoff)
      options = { max_match_bytes: MAX_MATCH_BYTES }
      return options.merge(cutoff_options(content_match_cutoff)) if query.filters.empty?

      including, excluding = query.filters.partition { |filter| !filter[:negated] }
      pathspecs = (including.first(1) + excluding).map { |filter| pathspec_for(filter) }
      return options if pathspecs.size > MAX_PATHSPECS || pathspecs.any?(&:nil?)

      options[:pathspecs] = pathspecs
      # Git ORs positive pathspecs while filters are ANDed, so with more than one the matches are a superset and a
      # cutoff could drop matches that pass the filters.
      options.merge!(cutoff_options(content_match_cutoff)) if including.size <= 1
      options
    end

    # `limit` stops reading the response in Rails, `gitaly_limit` stops `git grep` in Gitaly.
    def cutoff_options(content_match_cutoff)
      { limit: content_match_cutoff, gitaly_limit: content_match_cutoff }
    end

    # Git matches pathspecs case-insensitively for ASCII only, and normalizes "//", "/./" and "/../", so values with
    # those can't be pushed down. A leading "./" or "../" is fine: it follows the pattern's "*", so Git keeps it as is.
    def pathspec_for(filter)
      value = filter[:value]
      return if !value.ascii_only? || value.include?("\0") || value.match?(%r{/(\.{1,2}(/|\z)|/)})

      pattern = PATHSPEC_PATTERNS.fetch(filter[:name]) % value.gsub(/[\\?\[]/) { |char| "\\#{char}" }
      pathspec = ":(#{'exclude,' if filter[:negated]}icase)#{pattern}"
      pathspec if pathspec.bytesize <= MAX_PATHSPEC_BYTES
    end

    def find_by_content(query, options)
      repository.search_files_by_content(query, ref, options).map do |result|
        Gitlab::Search::FoundBlob.new(content_match: result, project: project, ref: ref, repository: repository)
      end
    end

    def find_by_path(query)
      search_paths(query).map do |path|
        Gitlab::Search::FoundBlob.new(blob_path: path, path: path, project: project, ref: ref, repository: repository)
      end
    end

    # Overridden in Gitlab::WikiFileFinder
    def search_paths(query)
      return [] if query.blank? || ref.blank?

      escaped_query = RE2::Regexp.escape(query)
      query_regexp = Gitlab::EncodingHelper.encode_utf8_no_detect("(?i)#{escaped_query}")
      repository.search_files_by_regexp(query_regexp, ref)
    end
  end
end
