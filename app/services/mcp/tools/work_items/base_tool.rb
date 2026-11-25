# frozen_string_literal: true

module Mcp
  module Tools
    module WorkItems
      class BaseTool < Mcp::Tools::Base::GraphqlTool
        include Mcp::Tools::Concerns::ContentValidation
        include Mcp::Tools::Concerns::ResourceFinder
        include Mcp::Tools::Concerns::UrlParser

        def governed_containers
          [resolve_parent[:record]]
        end

        protected

        # Returns: { type: :project/:group, full_path: String, record: Project/Group }
        def resolve_parent
          @resolved_parent ||= params[:url] ? resolve_parent_from_url(params[:url]) : resolve_parent_from_id
        end

        # Returns: Work item global ID as String (e.g., "gid://gitlab/WorkItem/123")
        def resolve_work_item_id
          @resolved_work_item_id ||= resolve_work_item.to_global_id.to_s
        end

        def resolve_work_item
          @resolved_work_item ||= begin
            iid = work_item_iid
            find_work_item_in_parent!(resolve_work_item_parent, iid)
          end
        end

        def resolve_work_item_parent
          @resolved_work_item_parent ||= if params[:url]
                                           parsed = parsed_work_item_url
                                           find_parent_by_id_or_path!(parsed[:parent_type], parsed[:parent_path])
                                         else
                                           resolve_parent[:record]
                                         end
        end

        private

        def resolve_parent_from_id
          identifier = params[:project_id] || params[:group_id]
          parent_type = params[:project_id] ? :project : :group

          raise ArgumentError, 'Must provide either project_id or group_id' unless identifier

          parent = find_parent_by_id_or_path!(parent_type, identifier)

          { type: parent_type, full_path: parent.full_path, record: parent }
        end

        def work_item_iid
          return parsed_work_item_url[:work_item_iid] if params[:url]

          params[:work_item_iid] || raise(ArgumentError, 'Must provide work_item_iid')
        end

        def parsed_work_item_url
          @parsed_work_item_url ||= parse_work_item_url(params[:url])
        end
      end
    end
  end
end
