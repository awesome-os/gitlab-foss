# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::GrapeLogging::Middleware::RequestLogger, feature_category: :api do
  let(:instrumentation_key) { 'gitlab.grape_logging.request_logger_spec' }
  let(:downstream_response) { [200, { 'Content-Type' => 'text/plain' }, ['ok']] }
  let(:app) { instance_double(Grape::Endpoint, call: downstream_response) }
  let(:env) { Rack::MockRequest.env_for('/api/v4/projects', method: 'GET') }
  let(:logged_entries) { [] }

  subject(:middleware) { described_class.new(app, instrumentation_key: instrumentation_key) }

  def call_middleware
    subscriber = ->(*args) { logged_entries << args.last }

    ActiveSupport::Notifications.subscribed(subscriber, instrumentation_key) do
      middleware.call(env)
    end
  end

  context 'when the skip flag is absent' do
    it 'logs the request and returns the downstream response', :aggregate_failures do
      expect(::GrapeLogging::Timings).to receive(:reset_db_runtime).once.and_call_original

      expect(call_middleware).to eq(downstream_response)
      expect(app).to have_received(:call).with(env)
      expect(logged_entries.size).to eq(1)
      expect(logged_entries.first).to include(status: 200, method: 'GET', path: '/api/v4/projects')
    end
  end

  context 'when the skip flag is set' do
    before do
      env[described_class::SKIP_ENV_KEY] = true
    end

    it 'continues processing without logging', :aggregate_failures do
      expect(call_middleware).to eq(downstream_response)
      expect(app).to have_received(:call).with(env)
      expect(logged_entries).to be_empty
    end

    it 'bypasses the logger hooks, so the database timer is not reset' do
      expect(::GrapeLogging::Timings).not_to receive(:reset_db_runtime)

      call_middleware
    end
  end
end
