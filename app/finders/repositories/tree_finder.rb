# frozen_string_literal: true

module Repositories
  class TreeFinder
    include Gitlab::Utils::StrongMemoize

    CommitMissingError = Class.new(StandardError)

    attr_reader :next_cursor

    def initialize(project, params = {})
      @project = project
      @repository = project.repository
      @params = params
      @next_cursor = nil
    end

    def execute(gitaly_pagination: false)
      raise CommitMissingError unless commit_exists?

      request_params = { recursive: recursive, rescue_not_found: rescue_not_found, with_last_commit: with_last_commit }
      request_params[:pagination_params] = pagination_params if gitaly_pagination

      tree = repository.tree(commit.id, path, **request_params)

      @next_cursor = tree.cursor&.next_cursor if gitaly_pagination

      tree.sorted_entries
    end

    # @note Offset pagination otherwise reads the whole tree for every page after the first.
    def later_page_via_gitaly?
      page > 1 && gitaly_offset_enabled? && page_offset < total
    end
    strong_memoize_attr :later_page_via_gitaly?

    # @note An empty tree is left to Gitaly, so a missing path still raises and returns 404.
    def past_last_page?
      page > 1 && gitaly_offset_enabled? && total > 0 && page_offset >= total
    end

    # @note Kaminari leaves the counts out of later pages of large arrays. Keep the headers the same.
    def omit_offset_counts?
      later_page_via_gitaly? && total >= Kaminari::ActiveRecordRelationMethods::MAX_COUNT_LIMIT
    end

    def total
      # This is inefficient and we'll look at replacing this implementation
      cache_key = [project, repository.commit, :tree_size, commit.id, path, recursive]
      Gitlab::Cache.fetch_once(cache_key) do
        repository.tree(commit.id, path, recursive: recursive).entries.size
      end
    end
    strong_memoize_attr :total

    def commit_exists?
      commit.present?
    end

    private

    attr_reader :project, :repository, :params

    def commit
      @commit ||= project.commit(ref)
    end

    def ref
      params[:ref] || project.default_branch
    end

    def path
      params[:path]
    end

    def recursive
      params[:recursive]
    end

    def rescue_not_found
      params[:rescue_not_found]
    end

    def with_last_commit
      params.fetch(:with_last_commit, false)
    end

    def pagination_params
      pagination = { limit: per_page, page_token: params[:page_token] }
      pagination[:offset] = page_offset if later_page_via_gitaly?
      pagination
    end

    def page_offset
      (page - 1) * per_page
    end

    def page
      (params[:page] || 1).to_i
    end

    def per_page
      (params[:per_page] || Kaminari.config.default_per_page).to_i
    end

    # @note Kaminari caps per_page for later pages, so offsets only line up with its pages below
    #   that cap. Gitaly rejects an offset combined with a page token.
    def gitaly_offset_enabled?
      params[:pagination] == 'legacy' &&
        params[:page_token].blank? &&
        per_page.between?(1, Kaminari.config.max_per_page) &&
        Feature.enabled?(:tree_offset_pagination_gitaly_offset, project)
    end
  end
end
