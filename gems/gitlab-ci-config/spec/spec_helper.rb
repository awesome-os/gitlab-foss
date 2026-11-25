# frozen_string_literal: true

require 'rspec-parameterized'

require 'gitlab_ci_config'

RSpec.configure do |config|
  config.threadsafe = false

  config.example_status_persistence_file_path = ".rspec_status"

  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.around(:example, :request_store) do |example|
    Gitlab::SafeRequestStore.ensure_request_store { example.run }
  end
end
