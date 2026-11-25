# frozen_string_literal: true

module Resolvers
  module Wikis
    class WikiPageVersionsResolver < BaseResolver
      description 'List versions of a wiki page, most recent first.'

      authorizes_object!
      authorize :read_wiki

      calls_gitaly!

      type Types::Wikis::WikiPageVersionType.connection_type, null: true

      def resolve(first: nil, after: nil)
        limit = page_size(first)
        offset = decode_cursor(after)

        page = object.wiki.find_page(object.canonical_slug, load_content: false)
        return empty_result unless page

        history = ::Wikis::PageHistory.new(page)
        return empty_result(total_count: -> { history.count }) if limit <= 0

        versions = history.paginated_versions(limit: limit + 1, offset: offset)

        has_next_page = versions.size > limit
        end_cursor = encode_cursor(offset + limit) if has_next_page

        Gitlab::Graphql::ExternallyPaginatedArray.new(
          nil, end_cursor, *versions.first(limit),
          has_next_page: has_next_page, total_count: -> { history.count }
        )
      end

      private

      def page_size(first)
        [first, field.max_page_size || context.schema.default_max_page_size].compact.min # rubocop:disable Graphql/Descriptions -- false positive on `field`
      end

      def encode_cursor(offset)
        Base64.strict_encode64(offset.to_s)
      end

      def decode_cursor(cursor)
        return 0 if cursor.blank?

        [Integer(Base64.strict_decode64(cursor), 10), 0].max
      rescue ArgumentError, TypeError
        raise Gitlab::Graphql::Errors::ArgumentError, 'Invalid pagination cursor'
      end

      def empty_result(total_count: 0)
        Gitlab::Graphql::ExternallyPaginatedArray.new(nil, nil, has_next_page: false, total_count: total_count)
      end
    end
  end
end
