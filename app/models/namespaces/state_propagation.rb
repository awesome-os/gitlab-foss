# frozen_string_literal: true

module Namespaces
  class StatePropagation < ApplicationRecord
    self.table_name = 'namespace_state_propagations'

    belongs_to :namespace, class_name: 'Namespace', optional: false

    enum :status, { pending: 0, processing: 1 }, prefix: true
    enum :source_state, Namespace.states, prefix: true
    enum :target_state, Namespace.states, prefix: true

    validates :source_state, presence: true
    validates :target_state, presence: true
    validates :status, presence: true

    scope :pending, -> { status_pending }
    scope :processing, -> { status_processing }
    scope :order_by_created_at_asc, -> { order(created_at: :asc) }
    scope :stuck_processing, ->(threshold) { processing.where(started_at: ..threshold) }
    scope :stale_pending, ->(threshold) { pending.where(created_at: ..threshold) }
    scope :with_namespace_route, -> { preload(namespace: :route) }

    # Records for one namespace are applied in id order, which matches commit order
    # because the transition holds the namespace row lock when it inserts the record.
    #
    # @param namespace_id [Integer]
    # @return [Namespaces::StatePropagation, nil] the oldest record of the namespace, whatever its status
    def self.next_for(namespace_id)
      where(namespace_id: namespace_id).order(:id).first
    end

    def self.counts_by_status
      group(:status).count
    end

    # Copies the current traversal ids onto the records of a namespace and its descendants
    # after the namespace moved to another parent.
    #
    # @param namespace_id [Integer] the moved namespace
    # @param root_id [Integer] the root of the hierarchy it moved out of
    def self.refresh_traversal_ids_for_subtree(namespace_id, root_id:)
      where('(traversal_ids[1]) = ?', root_id)
        .where("traversal_ids @> '{?}'", namespace_id)
        .update_all(
          'traversal_ids = (SELECT namespaces.traversal_ids FROM namespaces ' \
            'WHERE namespaces.id = namespace_state_propagations.namespace_id)'
        )
    end

    def claim
      now = Time.current

      self.class.pending.where(id: id)
        .update_all(status: self.class.statuses[:processing], started_at: now, updated_at: now) == 1
    end

    # Returns a processing record to pending so it can be claimed again.
    #
    # @return [Integer] the number of records released, 0 when the record is not processing
    def release
      self.class.processing.where(id: id)
        .update_all(status: self.class.statuses[:pending], started_at: nil, updated_at: Time.current)
    end
  end
end
