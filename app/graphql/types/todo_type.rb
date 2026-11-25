# frozen_string_literal: true

module Types
  class TodoType < BaseObject
    graphql_name 'Todo'
    description 'Representing a to-do entry'

    connection_type_class Types::CountableConnectionType

    present_using TodoPresenter

    authorize :read_todo
    authorize_granular_token permissions: :read_todo, boundary: :user, boundary_type: :user

    def self.authorization_scopes
      super + [:ai_workflows]
    end

    field :id, GraphQL::Types::ID,
      description: 'ID of the to-do item.',
      null: false,
      scopes: [:api, :read_api, :ai_workflows]

    field :project, Types::ProjectType,
      description: 'Project the to-do item is associated with.',
      null: true

    field :group, 'Types::GroupType',
      description: 'Group the to-do item is associated with.',
      null: true

    field :author, Types::UserType,
      description: 'Author of the to-do item.',
      null: false

    field :action, Types::TodoActionEnum,
      description: 'Action of the to-do item.',
      null: false,
      scopes: [:api, :read_api, :ai_workflows]

    field :target, Types::TodoableInterface,
      description: 'Target of the to-do item.',
      calls_gitaly: true,
      deprecated: {
        reason: 'Under certain circumstances, the `target` field on a to-do item can be `null`. ' \
          'The GraphQL schema currently declares `target` field as non-nullable. ' \
          'Use the new `target_entity` field instead',
        milestone: '17.4'
      },
      null: false

    field :target_entity, Types::TodoableInterface,
      description: 'Target of the to-do item.',
      calls_gitaly: true,
      null: true

    field :target_type, Types::TodoTargetEnum,
      description: 'Target type of the to-do item.',
      null: false

    field :target_url, GraphQL::Types::String, # rubocop:disable GraphQL/ExtractType -- Target already exists
      description: 'URL of the to-do item target.',
      null: true,
      scopes: [:api, :read_api, :ai_workflows]

    field :transfer_failed_retry_url, GraphQL::Types::String,
      description: 'URL that retries a transfer-failed to-do item.',
      null: true,
      scopes: [:api, :read_api, :ai_workflows]

    field :transfer_failure_reason, GraphQL::Types::String, # rubocop:disable GraphQL/ExtractType -- sits alongside the existing transfer_failed_retry_url field
      description: 'Reason the transfer failed, for a transfer-failed to-do item.',
      null: true,
      scopes: [:api, :read_api, :ai_workflows]

    field :body, GraphQL::Types::String,
      description: 'Body of the to-do item.',
      null: false,
      scopes: [:api, :read_api, :ai_workflows],
      calls_gitaly: true # TODO This is only true when `target_type` is `Commit`. See https://gitlab.com/gitlab-org/gitlab/issues/34757#note_234752665

    field :state, Types::TodoStateEnum,
      description: 'State of the to-do item.',
      null: false,
      scopes: [:api, :read_api, :ai_workflows]

    field :created_at, Types::TimeType,
      description: 'Timestamp the to-do item was created.',
      null: false,
      scopes: [:api, :read_api, :ai_workflows]

    field :note, Types::Notes::NoteType,
      description: 'Note which created the to-do item.',
      null: true

    field :member_access_type, GraphQL::Types::String,
      description: 'Access type of access request to-do items.',
      null: true

    field :review_id, ::Types::GlobalIDType[::Review],
      description: 'Global ID of the review whose publication raised the to-do item. ' \
        '`null` for other actions and when no review is tied to the item.',
      null: true,
      experiment: { milestone: '19.7' }

    field :snoozed_until, Types::TimeType,
      description: 'Time until when the todo is snoozed.',
      null: true

    def project
      Gitlab::Graphql::Loaders::BatchModelLoader.new(Project, object.project_id).find
    end

    def group
      Gitlab::Graphql::Loaders::BatchModelLoader.new(Group, object.group_id).find
    end

    def author
      Gitlab::Graphql::Loaders::BatchModelLoader.new(User, object.author_id).find
    end

    def target
      target_entity
    end

    # @note The interface path (CurrentUserTodos) loads to-dos without the model preload scopes.
    def review_id
      return unless object.review_submitted?

      BatchLoader::GraphQL.for(unpresented).batch do |todos, loader|
        ActiveRecord::Associations::Preloader.new(records: todos, associations: :review_link).call

        todos.each { |todo| loader.call(todo, todo.review_id) }
      end
    end

    # rubocop: disable GraphQL/ResolverMethodLength -- every target source stays inline in one method, as asked in review
    def target_entity
      if object.for_commit?
        Gitlab::Graphql::Loaders::BatchCommitLoader.new(
          container_class: Project,
          container_id: object.project_id,
          oid: object.commit_id
        ).find
      elsif object.association(:target).loaded? && reuse_preloaded_target?
        object.target
      else
        Gitlab::Graphql::Loaders::BatchModelLoader.new(target_type_class, object.target_id).find
      end
    end
    # rubocop: enable GraphQL/ResolverMethodLength

    private

    def reuse_preloaded_target?
      Feature.enabled?(:graphql_todo_target_entity_reuse_preloaded, Feature.current_request)
    end

    def target_type_class
      klass = object.target_type.safe_constantize
      raise "Invalid target type \"#{object.target_type}\"" unless klass < Todoable

      klass
    end
  end
end

Types::TodoType.prepend_mod
