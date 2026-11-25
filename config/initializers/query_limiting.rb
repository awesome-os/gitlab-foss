# frozen_string_literal: true

if Gitlab::QueryLimiting.enabled_for_env?
  require 'gitlab/query_limiting/active_support_subscriber'
  require 'gitlab/query_limiting/transaction'
  require 'gitlab/query_limiting/middleware'

  Gitlab::Application.configure do |config|
    config.middleware.use(Gitlab::QueryLimiting::Middleware)
  end
end
