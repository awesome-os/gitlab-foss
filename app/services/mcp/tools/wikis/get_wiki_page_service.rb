# frozen_string_literal: true

module Mcp
  module Tools
    module Wikis
      class GetWikiPageService < Base::GraphqlService
        MAX_LIMIT = ::Mcp::Tools::Concerns::LineWindow::MAX_LIMIT

        register_version '0.1.0', {
          toolset: :wikis,
          description: 'Get a wiki page, including its content, from a GitLab project or group. ' \
            'Identify the container with exactly one of project_id or group_id. For large pages, use offset ' \
            'and limit to read in windows; when the response is partial, system_instruction gives the next offset.',
          annotations: {
            title: 'Get wiki page',
            readOnlyHint: true,
            idempotentHint: true,
            openWorldHint: false
          },
          input_schema: {
            type: 'object',
            required: %w[slug],
            properties: {
              slug: {
                type: 'string',
                description: 'URL slug of the wiki page.'
              },
              project_id: {
                type: 'string',
                description: 'ID or path of the project. Required if group_id is not provided.'
              },
              group_id: {
                type: 'string',
                description: 'ID or path of the group. Required if project_id is not provided.'
              },
              offset: {
                type: 'integer',
                description: 'Zero-indexed line number to start reading from. ' \
                  'Omit to start at the beginning of the page.',
                minimum: 0
              },
              line_byte_offset: {
                type: 'integer',
                description: 'Byte position in the line at offset to start from. ' \
                  'Use the value system_instruction gives after a long line is cut.',
                minimum: 0
              },
              limit: {
                type: 'integer',
                description: "Maximum number of lines to return. The maximum is #{MAX_LIMIT}.",
                minimum: 1,
                maximum: MAX_LIMIT
              }
            }
          }
        }

        protected

        def graphql_tool_class
          Mcp::Tools::Wikis::GetWikiPageTool
        end

        def perform_v0_1_0(arguments)
          execute_graphql_tool(arguments)
        end
      end
    end
  end
end
