# frozen_string_literal: true

module Packages
  module Npm
    # No-op: nothing enqueues this worker since
    # https://gitlab.com/gitlab-org/gitlab/-/merge_requests/215599. Remove in
    # https://gitlab.com/gitlab-org/gitlab/-/issues/483495.
    class DeprecatePackageWorker
      include ApplicationWorker

      data_consistency :sticky
      queue_namespace :package_repositories
      feature_category :package_registry
      deduplicate :until_executed
      urgency :low
      idempotent!

      def perform(_project_id, _params); end
    end
  end
end
