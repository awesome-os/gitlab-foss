# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::SidekiqMiddleware::MarkdownCacheRefreshBatch, feature_category: :markdown do
  subject(:middleware) { described_class.new }

  before do
    allow(Gitlab::MarkdownCache::RefreshWorker).to receive(:perform_async)
  end

  it 'enqueues the refreshes of a job once it has run' do
    result = middleware.call(nil, {}, 'default') do
      Gitlab::MarkdownCache::RefreshBatch.add(build_stubbed(:note, id: 1))
      expect(Gitlab::MarkdownCache::RefreshWorker).not_to have_received(:perform_async)

      :done
    end

    expect(result).to eq(:done)
    expect(Gitlab::MarkdownCache::RefreshWorker).to have_received(:perform_async).with('Note', [1])
  end

  it 'is the innermost server middleware' do
    expect(Gitlab::SidekiqMiddleware::Server.middlewares.last).to eq(described_class)
  end
end
