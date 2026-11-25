# frozen_string_literal: true

require_relative 'bundler_setup'

# Coverage tracks only files loaded after it starts. Coverband reuses this run.
if %w[1 yes true].include?(ENV['COVERBAND_ENABLED'].to_s.downcase)
  require 'coverage'
  Coverage.start(oneshot_lines: false)
end

enable_bootsnap_default_value = ENV['RAILS_ENV'] != 'production' ? '1' : '0'
if %w[1 yes true].include?(ENV.fetch('ENABLE_BOOTSNAP', enable_bootsnap_default_value))
  require 'bootsnap/setup'

  # Record Bootsnap compile cache hit/miss events so the hit rate can be reported
  # once boot finishes (see Gitlab::Metrics::BootTimeTracker). The callback must
  # be installed here, right after Bootsnap.setup installs its compile cache
  # hooks and before the application requires the bulk of its code, so that the
  # events that happen during boot are captured.
  require_relative '../lib/gitlab/bootsnap_cache_store'
  Gitlab::BootsnapCacheStore.enable!
  Bootsnap.instrumentation = ->(event, _path) do
    Gitlab::BootsnapCacheStore.increment(event)
  end
end
