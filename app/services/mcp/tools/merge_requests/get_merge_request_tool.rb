# frozen_string_literal: true

module Mcp
  module Tools
    module MergeRequests
      class GetMergeRequestTool < Mcp::Tools::Base::GraphqlTool
        extend Gitlab::Utils::Override
        include Mcp::Tools::Concerns::ResourceFinder
        include Mcp::Tools::Concerns::CursorPagination
        include Mcp::Tools::Concerns::SuggestionIdUnwrapping

        DEFAULT_NOTES_PAGE_SIZE = 100

        def self.build_query
          load_graphql('merge_requests/get_merge_request.query.graphql')
        end

        register_version VERSIONS[:v0_1_0], {
          operation_name: 'project',
          graphql_operation: build_query
        }

        def governed_containers
          [resolve_target.first]
        end

        def build_variables
          project, iid = resolve_target
          facets = Array(params[:include]).map(&:to_s)
          detail = params[:detail].to_s
          diffs_requested = facets.include?('diffs')

          # Full patches plus several facets exceed the GraphQL max complexity (307 > 250 with all seven).
          if diffs_requested && detail == 'full_patch' && facets.uniq.size > 1
            raise ArgumentError,
              'detail=full_patch cannot be combined with other include facets. Request include: ["diffs"] ' \
                'on its own, then the other facets in a second call.'
          end

          {
            fullPath: project.full_path,
            iid: iid.to_s,
            includeDiffs: diffs_requested,
            includeDiffFiles: diffs_requested && detail != 'none',
            includeDiffPatches: diffs_requested && detail == 'full_patch',
            includeCommits: facets.include?('commits'),
            includeNotes: facets.include?('notes'),
            includePipelines: facets.include?('pipelines'),
            includeDiscussions: facets.include?('discussions'),
            includeApprovals: facets.include?('approvals'),
            includeConflicts: facets.include?('conflicts'),
            **notes_pagination_variables(facets),
            diffsAfter: params[:diffs_after],
            diffsFirst: params[:diffs_first],
            commitsAfter: params[:commits_after],
            commitsFirst: params[:commits_first],
            pipelinesAfter: params[:pipelines_after],
            pipelinesFirst: params[:pipelines_first]
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

        def resolve_target
          @resolve_target ||=
            if params[:url].present?
              match = ::MergeRequest.link_reference_pattern.match(params[:url].to_s)
              raise ArgumentError, "Invalid merge request URL: #{params[:url]}" unless match

              [find_project!("#{match[:namespace]}/#{match[:project]}"), match[:merge_request]]
            else
              iid = params[:merge_request_iid]
              project_id = params[:project_id]

              raise ArgumentError, 'Provide either url, or project_id and merge_request_iid' unless iid && project_id

              [find_project!(project_id), iid]
            end
        end

        def process_result(result)
          missing = missing_resource(result)
          return missing_resource_error(missing) if missing

          processed_result = super
          return processed_result if processed_result[:isError]

          merge_request = unwrap_suggestion_ids(processed_result[:structuredContent]['mergeRequest'])
          formatted_content = [{ type: 'text', text: Gitlab::Json.dump(merge_request) }]
          ::Mcp::Tools::Base::Response.success(formatted_content, merge_request)
        end

        def missing_resource(result)
          return if result['errors'].present?

          project = result.dig('data', 'project')
          return 'Project' if project.nil?

          'Merge request' if project['mergeRequest'].nil?
        end

        def missing_resource_error(resource)
          ::Mcp::Tools::Base::Response.error(
            "#{resource} not found or inaccessible", reason: ::Mcp::Tools::Base::Response::Reason::NOT_FOUND
          )
        end
      end
    end
  end
end

Mcp::Tools::MergeRequests::GetMergeRequestTool.prepend_mod
