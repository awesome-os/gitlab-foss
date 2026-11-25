# frozen_string_literal: true

# Build the Grape router in the Puma master so that workers share it instead of each
# compiling it on its first API request. With api_mount_only_for_api_paths the config.ru
# warmup no longer reaches Grape, and zz_metrics.rb compiles it only with Prometheus metrics on.
return unless Gitlab::Runtime.puma? && Rails.application.config.eager_load

Gitlab::Cluster::LifecycleEvents.on_before_fork do
  API::API.compile!
end
