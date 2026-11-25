# frozen_string_literal: true

module Ci
  class BuildName < Ci::ApplicationRecord
    include PgFullTextSearchable
    include Ci::Partitionable

    MAX_JOB_NAME_LENGTH = 255

    self.table_name = :p_ci_build_names
    self.primary_key = :build_id

    query_constraints :build_id, :partition_id
    partitionable partitioned: true

    # rubocop:disable Rails/InverseOf -- Will be added once association on build is added
    belongs_to :build,
      class_name: 'Ci::Build',
      foreign_key: [:build_id, :partition_id],
      primary_key: [:id, :partition_id]
    # rubocop:enable Rails/InverseOf

    validates :build, presence: true
    validates :name, presence: true, length: { maximum: MAX_JOB_NAME_LENGTH }
    validates :project_id, presence: true

    def name=(value)
      super(value&.truncate(MAX_JOB_NAME_LENGTH))
    end
  end
end
