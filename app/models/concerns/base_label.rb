# frozen_string_literal: true

module BaseLabel # rubocop:disable Gitlab/BoundedContexts -- existing Label modules/classes are not bounded
  extend ActiveSupport::Concern

  DEFAULT_COLOR = ::Gitlab::Color.of('#6699cc')

  included do
    include CacheMarkdownField
    include Gitlab::SQL::Pattern

    cache_markdown_field :description, pipeline: :single_line

    attribute :color, ::Gitlab::Database::Type::Color.new, default: DEFAULT_COLOR

    before_validation :strip_whitespace_from_title

    validates :color, color: true, presence: true

    # Don't allow ',' for label titles
    validates :title, presence: true, format: { with: /\A[^,]+\z/ }
    validates :title, length: { maximum: 255 }

    # Searches for labels with a matching title or description.
    #
    # This method uses ILIKE on PostgreSQL.
    #
    # query - The search query as a String.
    #
    # Returns an ActiveRecord::Relation.
    def self.search(query, **options)
      search_in = searchable_columns(options[:search_in])

      return fuzzy_search(query, search_in) unless options[:fuzzy_search]

      subsequence_search(query, search_in)
    end

    # Orders labels whose title equals the query, ignoring case, first, then by title and id.
    # Used by {LabelsFinder#sort} for non-fuzzy search so a limit never cuts off the exact match.
    def self.order_exact_title_matches_first(query)
      order_by_match_tiers(exact_title_match_order(query))
    end

    # Orders labels so exact title matches come first, then labels containing the query as a
    # contiguous substring, then fuzzy-only matches.
    # Used by {LabelsFinder#sort} when fuzzy search is on, in place of the default alphabetical order.
    #
    # @param query [String] the user's search term
    # @param options [Hash] search options
    # @option options [Array<Symbol>] :search_in `[:title]` searches titles, `[:description]` searches
    #   descriptions, any other value (including nil) searches both
    # @return [ActiveRecord::Relation] labels ordered by exact title match, contiguous match, title,
    #   then id; also projects `exact_title` and `contiguous` columns into the SELECT
    def self.order_contiguous_matches_first(query, **options)
      columns = searchable_columns(options[:search_in])
      contiguous = columns.map { |column| fuzzy_arel_match(column, query) }.reduce(:or)
      contiguous = Arel::Nodes::Case.new.when(Arel::Nodes::Grouping.new(contiguous)).then(1).else(0)

      order_by_match_tiers(
        exact_title_match_order(query),
        Gitlab::Pagination::Keyset::ColumnOrderDefinition.new(
          attribute_name: 'contiguous',
          column_expression: contiguous,
          order_expression: contiguous.desc,
          order_direction: :desc,
          nullable: :not_nullable,
          add_to_projections: true
        )
      )
    end

    def self.exact_title_match_order(query)
      lower_query = Arel::Nodes::NamedFunction.new('LOWER', [Arel::Nodes.build_quoted(query.strip)])
      exact = Arel::Nodes::NamedFunction.new('LOWER', [arel_table[:title]]).eq(lower_query)
      exact = Arel::Nodes::Case.new.when(exact).then(1).else(0)

      Gitlab::Pagination::Keyset::ColumnOrderDefinition.new(
        attribute_name: 'exact_title',
        column_expression: exact,
        order_expression: exact.desc,
        order_direction: :desc,
        nullable: :not_nullable,
        add_to_projections: true
      )
    end
    private_class_method :exact_title_match_order

    def self.order_by_match_tiers(*tiers)
      order = Gitlab::Pagination::Keyset::Order.build(
        [
          *tiers,
          Gitlab::Pagination::Keyset::ColumnOrderDefinition.new(
            attribute_name: 'title',
            column_expression: arel_table[:title],
            order_expression: arel_table[:title].asc,
            nullable: :nulls_last
          ),
          Gitlab::Pagination::Keyset::ColumnOrderDefinition.new(
            attribute_name: 'id',
            order_expression: arel_table[:id].asc
          )
        ])

      order.apply_cursor_conditions(reorder(order))
    end
    private_class_method :order_by_match_tiers

    # Matches labels containing the characters of `query` in order, but not
    # necessarily contiguously ('bugu' matches 'bug::ux'). Whitespace is
    # ignored, mirroring client-side fuzzaldrin-plus matching.
    def self.subsequence_search(query, columns)
      pattern = "%#{query.gsub(/\s/, '').chars.map { |char| sanitize_sql_like(char) }.join('%')}%"

      where(columns.map { |column| arel_table[column].matches(pattern) }.reduce(:or))
    end
    private_class_method :subsequence_search

    def self.searchable_columns(search_in)
      case search_in
      when [:title]
        [:title]
      when [:description]
        [:description]
      else
        [:title, :description]
      end
    end
    private_class_method :searchable_columns

    # Override Gitlab::SQL::Pattern.min_chars_for_partial_matching as
    # label queries are never global, and so will not use a trigram
    # index. That means we can have just one character in the LIKE.
    def self.min_chars_for_partial_matching
      1
    end

    def color
      super || DEFAULT_COLOR
    end

    def text_color
      color.contrast
    end

    def name=(value)
      self.title = value
    end

    private

    def strip_whitespace_from_title
      return unless title

      stripped = title.strip
      # Skip the attribute write when nothing changed; this avoids a needless
      # AR mutation (which would raise FrozenError on a `let_it_be`-frozen
      # subject) and is the dominant case after the first validation pass.
      self[:title] = stripped unless stripped == title
    end
  end
end
