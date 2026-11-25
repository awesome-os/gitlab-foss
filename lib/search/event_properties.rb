# frozen_string_literal: true

module Search
  # Filter names and query operator classes for the `perform_search` event. Only names,
  # fixed-choice values and operator classes leave this class, never text a user typed.
  class EventProperties
    NONE = 'none'

    FIXED_CHOICE_FILTERS = {
      state: %w[opened closed merged],
      fields: %w[title]
    }.freeze

    NO_FILTER_VALUES = { state: %w[all] }.freeze

    BOOLEAN_FILTERS = %i[confidential include_archived exclude_forks regex].freeze

    # Recorded by name only: their values are user data or free text. `repository_ref` is left
    # out: the header search sends the current ref as context, not as a filter someone chose.
    NAME_ONLY_FILTERS = %i[
      language work_item_type_ids
      label_name label_names not_label_names or_label_names none_label_names any_label_names
      source_branch not_source_branch target_branch not_target_branch
      author_username not_author_username
      assignee_ids not_assignee_ids or_assignee_ids none_assignees any_assignees
      milestone_title not_milestone_title none_milestones any_milestones milestone_state_filters
      created_after created_before updated_after updated_before
      weight not_weight none_weight any_weight
      health_status not_health_status none_health_status any_health_status
    ].freeze

    # `Search::Params` turns `type` into `work_item_type_ids`; record the name callers send.
    FILTER_NAMES = { work_item_type_ids: 'type' }.freeze

    ADVANCED_SYNTAX_FILTERS = {
      'blobs' => %w[filename path extension blob],
      'wiki_blobs' => %w[filename path extension]
    }.freeze
    BASIC_SYNTAX_FILTERS = {
      'blobs' => %w[filename path extension],
      'wiki_blobs' => %w[filename path extension]
    }.freeze
    # `Search::Zoekt::Query#available_syntax_filters`, which CE code can't reference. `repo` is
    # only parsed where the repo filter is available, and is recorded everywhere.
    ZOEKT_SYNTAX_FILTERS = %w[c case f file lang sym repo extension filename path].freeze
    ALL_SYNTAX_FILTERS = (ADVANCED_SYNTAX_FILTERS.values.flatten + ZOEKT_SYNTAX_FILTERS).uniq.freeze
    # Narrow by file or path; the other syntax filters are recorded as `syntax_filter`.
    FILE_FILTERS = %w[f file filename path extension blob].freeze

    # Search looks an iid up only when it ends the query. Basic search reads `#` for merge requests too.
    REFERENCES = { 'work_items' => /#\d+\z/, 'issues' => /#\d+\z/, 'merge_requests' => /!\d+\z/ }.freeze
    BASIC_REFERENCES = REFERENCES.merge('merge_requests' => /#\d+\z/).freeze

    # A lone or doubled sign (`-`, `--verbose`) is a literal, not an operator.
    EXCLUDE = ->(token) { token.length > 1 && token.start_with?('-') && !token.start_with?('--') }

    ADVANCED_TOKEN_OPERATORS = {
      'exclude' => EXCLUDE,
      'or' => ->(token) { token.include?('|') },
      'and' => ->(token) { token.length > 1 && token.start_with?('+') && !token.start_with?('++') },
      'prefix' => ->(token) { token.length > 1 && token.end_with?('*') },
      # `"a b"~2` is a phrase with slop, not a fuzzy term.
      'fuzzy' => ->(token) { token.length > 1 && token.match?(/~\d*\z/) && !token.match?(/"~\d*\z/) }
    }.freeze

    ZOEKT_REGEX_TOKEN_OPERATORS = {
      'exclude' => EXCLUDE,
      'or' => ->(token) { token == 'or' }
    }.freeze

    # @param params [Search::Params]
    # @param search_type [String] the engine that serves the search: basic, advanced or zoekt
    # @param scope [String]
    def initialize(params:, search_type:, scope:)
      @params = params
      @search_type = search_type.to_s
      @scope = scope.to_s
    end

    # @return [Hash{Symbol => String}] sorted, comma-joined filters and operators, or `none`
    def to_h
      { filters: join(filters), operators: join(operators) }
    end

    private

    attr_reader :params, :search_type, :scope

    def filters
      fixed_choice_filters + boolean_filters + name_only_filters
    end

    def fixed_choice_filters
      FIXED_CHOICE_FILTERS.filter_map do |name, choices|
        values = Array(param(name)).map(&:to_s).compact_blank - NO_FILTER_VALUES.fetch(name, [])
        next if values.empty?

        values.all? { |value| choices.include?(value) } ? "#{name}=#{values.sort.join('|')}" : name.to_s
      end
    end

    def boolean_filters
      BOOLEAN_FILTERS.filter_map do |name|
        value = boolean_param(name, default: nil)
        next if value.nil? || value == boolean_default(name)

        "#{name}=#{value}"
      end
    end

    def name_only_filters
      NAME_ONLY_FILTERS.filter_map do |name|
        next if Array.wrap(param(name)).compact_blank.empty?

        FILTER_NAMES.fetch(name, name.to_s)
      end
    end

    # @param name [Symbol]
    # @return [Boolean, nil] what the backend does when the param is absent
    # @note Zoekt excludes forks and uses regular expression mode only for an API request that
    #   omits the param. The web UI always sends `exclude_forks`, `false` unless the box is checked.
    def boolean_default(name)
      case name
      when :include_archived then false
      when :exclude_forks, :regex then param(:source).to_s == 'api'
      end
    end

    def operators
      tokens = params.query_string.to_s.split

      case search_type
      when 'advanced' then advanced_operators(tokens)
      when 'zoekt' then zoekt_operators(tokens)
      when 'basic' then basic_operators(tokens)
      else []
      end
    end

    def advanced_operators(tokens)
      syntax_filters = ADVANCED_SYNTAX_FILTERS.fetch(scope, [])
      query_tokens = tokens.reject { |token| syntax_filter?(token, syntax_filters) }

      syntax_filter_operators(tokens, syntax_filters) + phrase_operators + reference_operators(REFERENCES) +
        token_operators(query_tokens, ADVANCED_TOKEN_OPERATORS)
    end

    # @param tokens [Array<String>]
    # @return [Array<String>]
    # @note Exact match mode reads everything but the filters literally.
    def zoekt_operators(tokens)
      classes = syntax_filter_operators(tokens, ZOEKT_SYNTAX_FILTERS)
      return classes unless zoekt_regex_mode?

      query_tokens = tokens.reject { |token| syntax_filter?(token, ZOEKT_SYNTAX_FILTERS) }

      classes + phrase_operators + token_operators(query_tokens, ZOEKT_REGEX_TOKEN_OPERATORS)
    end

    # @param tokens [Array<String>]
    # @return [Array<String>]
    # @note Basic code and wiki search parse only syntax filters, and commit search sends the
    #   query to Gitaly as is. The other scopes match quoted phrases.
    def basic_operators(tokens)
      syntax_filters = BASIC_SYNTAX_FILTERS[scope]
      return syntax_filter_operators(tokens, syntax_filters) if syntax_filters
      return [] if scope == 'commits'

      phrase_operators + reference_operators(BASIC_REFERENCES)
    end

    def reference_operators(patterns)
      pattern = patterns[scope]
      pattern && params.query_string.to_s.match?(pattern) ? ['reference'] : []
    end

    def token_operators(tokens, matchers)
      matchers.filter_map { |name, matcher| name if tokens.any? { |token| matcher.call(token) } }
    end

    # @return [Array<String>]
    # @note Quotes around a filter value, as in `filename:"my file.rb"`, don't make a phrase.
    def phrase_operators
      quotes = 0
      in_filter_value = false

      params.query_string.to_s.split.each do |token|
        if in_filter_value
          in_filter_value = token.exclude?('"')
        elsif quoted_filter_value?(token)
          in_filter_value = token.count('"') == 1
        else
          quotes += token.count('"')
        end
      end

      quotes >= 2 ? ['phrase'] : []
    end

    def quoted_filter_value?(token)
      name, separator, value = token.delete_prefix('-').partition(':')
      separator.present? && value.start_with?('"') && ALL_SYNTAX_FILTERS.include?(name)
    end

    def syntax_filter_operators(tokens, names)
      tokens.filter_map do |token|
        next unless syntax_filter?(token, names)

        name = token.delete_prefix('-').partition(':').first
        kind = FILE_FILTERS.include?(name) ? 'file_filter' : 'syntax_filter'
        token.start_with?('-') ? "negated_#{kind}" : kind
      end
    end

    def syntax_filter?(token, names)
      name, separator, = token.delete_prefix('-').partition(':')
      separator.present? && names.include?(name)
    end

    def zoekt_regex_mode?
      boolean_param(:regex, default: boolean_default(:regex))
    end

    # @param name [Symbol]
    # @param default [Boolean, nil]
    # @return [Boolean, nil]
    # @note `Search::Params` leaves `regex` unconverted, and `to_boolean` raises on an Array or Hash.
    def boolean_param(name, default:)
      value = param(name)
      return default unless value.is_a?(String) || [true, false, 0, 1].include?(value)

      ::Gitlab::Utils.to_boolean(value, default: default)
    end

    def param(name)
      params.raw_params[name]
    end

    def join(values)
      values.empty? ? NONE : values.uniq.sort.join(',')
    end
  end
end
