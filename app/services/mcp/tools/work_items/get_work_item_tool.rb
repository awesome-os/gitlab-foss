# frozen_string_literal: true

module Mcp
  module Tools
    module WorkItems
      class GetWorkItemTool < BaseTool
        extend Gitlab::Utils::Override
        include Mcp::Tools::Concerns::CursorPagination

        DEFAULT_NOTES_PAGE_SIZE = 100

        register_version VERSIONS[:v0_1_0], {
          graphql_operation: load_graphql('work_items/get_work_item.query.graphql')
        }

        def governed_containers
          [resolve_work_item_parent]
        end

        def build_variables
          facets = Array(params[:include]).map(&:to_s)

          {
            id: resolve_work_item_id,
            includeNotes: facets.include?('notes'),
            includeDiscussions: facets.include?('discussions'),
            includeRelatedMergeRequests: facets.include?('related_merge_requests'),
            **notes_pagination_variables(facets),
            **discussions_variables(facets),
            relatedMergeRequestsFirst: params[:related_merge_requests_first] ||
              Mcp::Tools::Concerns::CursorPagination::DEFAULT_PAGE_SIZE,
            relatedMergeRequestsAfter: params[:related_merge_requests_after]
          }.compact
        end

        private

        override :default_page_size
        def default_page_size
          DEFAULT_NOTES_PAGE_SIZE
        end

        def notes_pagination_variables(facets)
          return {} unless facets.include?('notes')

          pagination_params = {
            first: params[:notes_first],
            after: params[:notes_after],
            last: params[:notes_last],
            before: params[:notes_before]
          }

          resolve_pagination_direction(pagination_params).transform_keys { |key| :"notes#{key.to_s.camelize}" }
        end

        # The discussions connection only pages forward, so there is no last/before pair here.
        def discussions_variables(facets)
          return {} unless facets.include?('discussions')

          {
            discussionsFirst: params[:discussions_first] || Mcp::Tools::Concerns::CursorPagination::DEFAULT_PAGE_SIZE,
            discussionsAfter: params[:discussions_after],
            discussionsFilter: params[:discussions_filter]&.upcase
          }
        end

        def resource_not_found_error
          ::Mcp::Tools::Base::Response.error(
            'Work item not found or inaccessible.', reason: ::Mcp::Tools::Base::Response::Reason::NOT_FOUND
          )
        end
      end
    end
  end
end
