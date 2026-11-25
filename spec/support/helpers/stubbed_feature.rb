# frozen_string_literal: true

# Extend the Feature class with the ability to stub feature flags.
module StubbedFeature
  extend ActiveSupport::Concern

  class MemoryAdapter < Flipper::Adapters::Memory
    def feature?(key)
      synchronize { @source.key?(key) }
    end
  end

  class_methods do
    # Turn stubbed feature flags on or off.
    def stub=(stub)
      @stub = stub
    end

    def stub?
      @stub.nil? ? true : @stub
    end

    # Wipe any previously set feature flags.
    def reset_flipper
      @flipper = nil
    end

    # Replace #flipper method with the optional stubbed/unstubbed version.
    def flipper
      if stub?
        @flipper ||= Flipper.new(MemoryAdapter.new)
      else
        super
      end
    end

    # Replace #enabled? method with the optional stubbed/unstubbed version.
    def enabled?(*args, **kwargs)
      feature_flag = super
      return feature_flag unless stub?

      # If feature flag is not persisted we mark the feature flag as enabled
      # We do `m.call` as we want to validate the execution of method arguments
      # and a feature flag state if it is not persisted
      unless Feature.persisted_name?(args.first)
        feature_flag = true
      end

      feature_flag
    end

    # Flipper::Adapters::Memory#features builds a Set of every stubbed name per call
    def persisted_name?(feature_name)
      return super unless stub?

      adapter = flipper.adapter
      adapter = adapter.adapter if adapter.is_a?(Flipper::Adapters::Memoizable)
      return super unless adapter.is_a?(MemoryAdapter)

      adapter.feature?(feature_name.to_s)
    end

    private

    def database_exists?
      # We use an in-memory store when stubbed so we can skip the DB existence checks
      return true if stub?

      super
    end
  end
end
