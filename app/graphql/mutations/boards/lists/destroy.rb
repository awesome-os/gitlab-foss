# frozen_string_literal: true

module Mutations
  module Boards
    module Lists
      class Destroy < ::Mutations::BaseMutation
        graphql_name 'DestroyBoardList'

        authorize_granular_token permissions: :delete_issue_board_list,
          boundaries: [
            { boundary_argument: :list_id, boundary: :project, boundary_type: :project },
            { boundary_argument: :list_id, boundary: :group, boundary_type: :group }
          ]

        field :list,
          Types::BoardListType,
          null: true,
          description: 'List after mutation.'

        argument :list_id, ::Types::GlobalIDType[::List],
          required: true,
          description: 'Global ID of the list to destroy. Only label lists are accepted.'

        def resolve(list_id:)
          list = load_list(list_id)
          raise_resource_not_available_error! unless can_admin_list?(list)

          response = ::Boards::Lists::DestroyService.new(list.board.resource_parent, current_user)
            .execute(list)

          {
            list: response.success? ? nil : list,
            errors: response.errors
          }
        end

        private

        def load_list(list_id)
          list = Gitlab::Graphql::Lazy.force(GitlabSchema.find_by_gid(list_id))
          # A missing record is a not-found error, as with the old `loads:`. Authorization
          # failures use raise_resource_not_available_error!, so we don't leak that it exists.
          raise GraphQL::ExecutionError, "No object found for `listId: #{list_id.to_s.inspect}`" unless list

          list
        end

        def can_admin_list?(list)
          return false unless list.present?

          Ability.allowed?(current_user, :admin_issue_board_list, list.board)
        end
      end
    end
  end
end
