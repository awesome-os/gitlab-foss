# frozen_string_literal: true

module DesignManagement
  class GitRepository < ::Repository
    extend ::Gitlab::Utils::Override

    # We define static git attributes for the design repository as this
    # repository is entirely GitLab-managed rather than user-facing.
    #
    # Enable all uploaded files to be stored in LFS.
    MANAGED_GIT_ATTRIBUTES = <<~GA.freeze
      /#{DesignManagement.designs_directory}/** filter=lfs diff=lfs merge=lfs -text
    GA

    # Override of a method called on Repository instances but sent via
    # method_missing to Gitlab::Git::Repository where it is defined
    def info_attributes
      @info_attributes ||= Gitlab::Git::AttributesParser.new(MANAGED_GIT_ATTRIBUTES)
    end

    # Override of a method called on Repository instances but sent via
    # method_missing to Gitlab::Git::Repository where it is defined
    def attributes(path)
      info_attributes.attributes(path)
    end

    # Override of a method called on Repository instances but sent via
    # method_missing to Gitlab::Git::Repository where it is defined
    def gitattribute(path, name)
      attributes(path)[name]
    end

    # Override of a method called on Repository instances but sent via
    # method_missing to Gitlab::Git::Repository where it is defined
    def attributes_at(_ref = nil)
      info_attributes
    end

    # Match the project repository so design and project object IDs use the
    # same hash. Falls back to the Gitaly default when the project has no repository.
    override :create_if_not_exists
    def create_if_not_exists(default_branch = nil)
      return if exists?

      super(default_branch, object_format: project.repository.object_format)
    end
  end
end
