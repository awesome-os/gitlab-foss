# frozen_string_literal: true

module Mcp
  module Tools
    module Wikis
      class GetWikiPageTool < Mcp::Tools::Base::GraphqlTool
        include Mcp::Tools::Concerns::ResourceFinder
        include Mcp::Tools::Concerns::LineWindow

        PARENT_PARAMS = %i[project_id group_id].freeze

        register_version VERSIONS[:v0_1_0], {
          graphql_operation: load_graphql('wikis/get_wiki_page.query.graphql'),
          operation_name: 'wikiPage'
        }

        def execute
          return wiki_unavailable_error if group_request? && !group_wikis_supported?

          super
        end

        def build_variables
          {
            slug: params[:slug],
            projectId: project&.to_global_id&.to_s,
            namespaceId: group&.to_global_id&.to_s
          }.compact
        end

        private

        def container_param
          provided = PARENT_PARAMS.select { |key| params[key].present? }

          raise ArgumentError, 'Provide exactly one of: project_id or group_id' unless provided.one?

          provided.first
        end

        def group_request?
          container_param == :group_id
        end

        # Overridden in EE to enable group wiki support.
        def group_wikis_supported?
          false
        end

        def project
          return unless container_param == :project_id

          @project ||= find_project!(params[:project_id])
        end

        def group
          return unless container_param == :group_id

          @group ||= find_group!(params[:group_id])
        end

        def wiki_unavailable_error
          ::Mcp::Tools::Base::Response.error(
            'Group wikis are not available on this instance. Use project_id to read a project wiki.',
            reason: ::Mcp::Tools::Base::Response::Reason::BAD_REQUEST
          )
        end

        def process_result(result)
          processed_result = super

          return processed_result if processed_result[:isError]

          data = processed_result[:structuredContent]
          window = line_window(
            data['content'],
            offset: params[:offset], limit: params[:limit], line_byte_offset: params[:line_byte_offset]
          )
          page = data.slice('title', 'slug', 'webUrl').merge(window.deep_stringify_keys)

          formatted_content = [{ type: 'text', text: Gitlab::Json.dump(page) }]
          ::Mcp::Tools::Base::Response.success(formatted_content, page)
        end

        def resource_not_found_error
          ::Mcp::Tools::Base::Response.error(
            "Wiki page '#{params[:slug]}' not found, or you do not have access to it.",
            reason: ::Mcp::Tools::Base::Response::Reason::NOT_FOUND
          )
        end
      end
    end
  end
end

Mcp::Tools::Wikis::GetWikiPageTool.prepend_mod
