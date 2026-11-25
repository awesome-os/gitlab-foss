# frozen_string_literal: true

module WorkItems
  module SavedViews
    class SavedView < ApplicationRecord
      include Spammable
      include Gitlab::SQL::Pattern

      # Natural sort key: digit runs are prefixed with their length (leading zeros
      # removed) so "Sprint 9" sorts before "Sprint 10". Other runs are lowercased.
      NATURAL_SORT_NAME_SQL = <<~SQL.squish.freeze
        (SELECT string_agg(
          CASE WHEN chunk[1] ~ '^[0-9]'
            THEN lpad(length(ltrim(chunk[1], '0'))::text, 3, '0') || ltrim(chunk[1], '0')
            ELSE lower(chunk[1])
          END, '' ORDER BY position)
        FROM regexp_matches(saved_views.name, '[0-9]+|[^0-9]+', 'g') WITH ORDINALITY AS chunks(chunk, position))
      SQL

      belongs_to :namespace
      belongs_to :author, foreign_key: :created_by_id, optional: true, inverse_of: :created_saved_views,
        class_name: 'User'
      belongs_to :updated_by, optional: true, class_name: 'User'

      has_many :user_saved_views, class_name: 'WorkItems::SavedViews::UserSavedView', inverse_of: :saved_view
      has_many :subscribed_users, through: :user_saved_views, source: :user

      scope :in_namespace, ->(namespace) { where(namespace_id: namespace.id) }
      scope :subscribed_by, ->(user) { joins(:user_saved_views).where(user_saved_views: { user_id: user.id }) }
      scope :search, ->(query) { fuzzy_search(query, [:name, :description]) }
      scope :preload_namespace, -> { preload(:namespace) }
      scope :authored_by, ->(user) { where(author: user) }
      scope :private_only, -> { where(private: true) }
      scope :public_only, -> { where(private: false) }
      scope :visible_to, ->(user) { user ? private_only.authored_by(user).or(public_only) : public_only }

      validates :name, presence: true, length: { maximum: 140 }
      validates :description, length: { maximum: 140 }, allow_blank: true
      validates :version, presence: true, numericality: { greater_than: 0 }
      validates :private, inclusion: { in: [true, false] }

      validates :filter_data, json_schema: { filename: "saved_view_filters", size_limit: 8.kilobytes }
      validates :display_settings,
        json_schema: { filename: 'work_item_user_preference_display_settings', size_limit: 8.kilobytes }

      attr_spammable :name, spam_title: true
      attr_spammable :description, spam_description: true

      enum :sort, ::WorkItems::SortingKeys.all.keys

      def self.sort_by_attributes(attribute, user: nil, scoped_to_subscribed: false)
        case attribute
        when :relative_position
          return order_relative_position(user) if user && scoped_to_subscribed

        when :name_asc
          order = Gitlab::Pagination::Keyset::Order.build([column_order_name_asc, column_order_id_desc])

          return order.apply_cursor_conditions(reorder(order))
        end

        order(id: :desc)
      end

      def self.column_order_name_asc
        natural_name = Arel.sql(NATURAL_SORT_NAME_SQL)

        Gitlab::Pagination::Keyset::ColumnOrderDefinition.new(
          attribute_name: 'natural_name',
          column_expression: natural_name,
          order_expression: natural_name.asc,
          order_direction: :asc,
          sql_type: 'text',
          add_to_projections: true
        )
      end

      def self.order_relative_position(user)
        relation = joins(:user_saved_views)
                     .where(user_saved_views: { user_id: user.id })
                     .order(Arel.sql('user_saved_views.relative_position ASC NULLS LAST'), id: :desc)

        relation.reorder(Gitlab::Pagination::Keyset::Order.build([column_order_relative_position,
          column_order_id_desc]))
      end

      def self.column_order_relative_position
        Gitlab::Pagination::Keyset::ColumnOrderDefinition.new(
          attribute_name: 'user_saved_views.relative_position',
          column_expression: UserSavedView.arel_table[:relative_position],
          order_expression: UserSavedView.arel_table[:relative_position].asc.nulls_last,
          nullable: :nulls_last
        )
      end

      def self.column_order_id_desc
        Gitlab::Pagination::Keyset::ColumnOrderDefinition.new(
          attribute_name: 'id',
          order_expression: SavedView.arel_table[:id].desc
        )
      end

      # Limit spam checks to public saved views in public namespaces
      def allow_possible_spam?(*)
        return true if Gitlab::CurrentSettings.allow_possible_spam
        return true if private?

        !namespace.public?
      end

      def unsubscribe_other_users!(user:)
        user_saved_views.where.not(user: user).delete_all
      end

      # Any other namespace type yields nil, which leaves no authorization boundary and fails closed.
      def resource_parent
        case namespace
        when ::Namespaces::ProjectNamespace then namespace.project
        when ::Group then namespace
        end
      end
    end
  end
end
