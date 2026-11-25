# frozen_string_literal: true

module Mutations
  module Boards
    module Lists
      class Update < BaseUpdate
        graphql_name 'UpdateBoardList'

        authorize_granular_token permissions: :update_issue_board_list,
          boundaries: [
            { boundary_argument: :list_id, boundary: :project, boundary_type: :project },
            { boundary_argument: :list_id, boundary: :group, boundary_type: :group }
          ]

        argument :list_id, Types::GlobalIDType[List],
          required: true,
          description: 'Global ID of the list.'

        field :list,
          Types::BoardListType,
          null: true,
          description: 'Mutated list.'

        def resolve(list_id:, **args)
          super(list: load_list(list_id), **args)
        end

        private

        def load_list(list_id)
          list = Gitlab::Graphql::Lazy.force(GitlabSchema.find_by_gid(list_id))
          # A missing record is a not-found error, as with the old `loads:`. BaseUpdate
          # raises raise_resource_not_available_error! when the user cannot read the list.
          raise GraphQL::ExecutionError, "No object found for `listId: #{list_id.to_s.inspect}`" unless list

          list
        end

        def update_list(list, args)
          service = ::Boards::Lists::UpdateService.new(list.board, current_user, args)
          service.execute(list)
        end

        def can_read_list?(list)
          Ability.allowed?(current_user, :read_issue_board_list, list.board)
        end
      end
    end
  end
end
