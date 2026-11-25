# frozen_string_literal: true

module DesignManagement
  DESIGN_IMAGE_SIZES = %w[v432x230].freeze

  # LFS and hashed repository storage are required for using Design Management.
  #
  # @param project [Project]
  # @return [Boolean]
  def self.enabled_for?(project)
    project.lfs_enabled? && project.hashed_storage?(:repository)
  end

  # Creates the design management repository record of the project if it does not exist yet.
  #
  # @param project [Project]
  # @return [DesignManagement::GitRepository]
  def self.repository_for(project)
    record = project.design_management_repository || project.create_design_management_repository
    record.repository
  end

  def self.designs_directory
    'designs'
  end

  def self.table_name_prefix
    'design_management_'
  end
end
