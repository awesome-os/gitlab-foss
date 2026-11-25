# frozen_string_literal: true

module Gitlab
  module Cleanup
    class RemoteUploads < RemoteObjectStorage
      extend ::Gitlab::Utils::Override

      def initialize(logger: nil)
        super(:uploads, ::Upload, logger: logger)
      end

      private

      # rubocop: disable CodeReuse/ActiveRecord -- this is not a reusable scope
      override :find_tracked_paths
      def find_tracked_paths(file_paths)
        tracked_paths = model_class.where(store: ObjectStorage::Store::REMOTE, path: file_paths).pluck(:path)
        tracked_paths += find_tracked_paths_without_upload_rows(file_paths - tracked_paths)

        file_paths.each do |file_path|
          log_file_tracked(file_path: file_path, is_tracked: tracked_paths.include?(file_path))
        end

        tracked_paths
      end
      # rubocop: enable CodeReuse/ActiveRecord

      # @note Some uploaders store files in this bucket without writing an `uploads` row.
      # @param file_paths [Array<String>] remote file paths with no `uploads` row
      # @return [Array<String>] the subset tracked by their own model instead
      def find_tracked_paths_without_upload_rows(_file_paths)
        []
      end
    end
  end
end

Gitlab::Cleanup::RemoteUploads.prepend_mod_with('Gitlab::Cleanup::RemoteUploads')
