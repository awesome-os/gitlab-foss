# frozen_string_literal: true

# Used for git housekeeping
#
# Ex.
#   ::Repositories::HousekeepingService.new(project).execute
#   ::Repositories::HousekeepingService.new(project.wiki).execute
#
module Repositories
  class HousekeepingService < BaseService
    include Gitlab::Utils::StrongMemoize

    # Timeout set to 24h
    LEASE_TIMEOUT = 86400
    GC_PERIOD = 200

    class LeaseTaken < StandardError
      def to_s
        "Somebody already triggered housekeeping for this resource in the past #{LEASE_TIMEOUT / 60} minutes"
      end
    end

    def initialize(resource, task = nil)
      @resource = resource
      @task = task
    end

    def execute
      lease_uuid = try_obtain_lease
      raise LeaseTaken unless lease_uuid.present?

      yield if block_given?

      execute_gitlab_shell_gc(lease_uuid)
    end

    def needed?
      pushes_since_gc > 0 && period_match? && housekeeping_enabled?
    end

    def increment!
      count = Gitlab::Metrics.measure(:increment_pushes_since_gc) do
        @resource.increment_pushes_since_gc
      end

      @pushes_since_gc = count if reuse_incremented_push_count?

      count
    end

    private

    def execute_gitlab_shell_gc(lease_uuid)
      @resource.git_garbage_collect_worker_klass.perform_async(@resource.id, task, lease_key, lease_uuid)
    ensure
      if pushes_since_gc >= gc_period
        Gitlab::Metrics.measure(:reset_pushes_since_gc) do
          @resource.reset_pushes_since_gc
        end

        @pushes_since_gc = 0
      end
    end

    def try_obtain_lease
      Gitlab::Metrics.measure(:obtain_housekeeping_lease) do
        lease = ::Gitlab::ExclusiveLease.new(lease_key, timeout: LEASE_TIMEOUT)
        lease.try_obtain
      end
    end

    def lease_key
      "#{@resource.class.name.underscore.pluralize}_housekeeping:#{@resource.id}"
    end

    # Seeded by #increment! so that a push decides on the counter value its own
    # increment produced, rather than on a later read a concurrent push may have moved.
    def pushes_since_gc
      return @resource.pushes_since_gc unless reuse_incremented_push_count?

      @pushes_since_gc ||= @resource.pushes_since_gc
    end

    # Read once per service instance, which is once per push.
    def reuse_incremented_push_count?
      Feature.enabled?(:housekeeping_reuse_incremented_push_count, feature_flag_actor)
    end
    strong_memoize_attr :reuse_incremented_push_count?

    def feature_flag_actor
      @resource.is_a?(Wiki) ? @resource.container : @resource
    end

    def task
      return @task if @task

      if pushes_since_gc % gc_period == 0
        :gc
      else
        :incremental_repack
      end
    end

    def period_match?
      [gc_period, repack_period].any? { |period| pushes_since_gc % period == 0 }
    end

    def housekeeping_enabled?
      Gitlab::CurrentSettings.housekeeping_enabled
    end

    def gc_period
      GC_PERIOD
    end

    def repack_period
      Gitlab::CurrentSettings.housekeeping_incremental_repack_period
    end
  end
end
