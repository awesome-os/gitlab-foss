# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Middleware::MarkdownCacheRefreshBatch, feature_category: :markdown do
  before do
    allow(Gitlab::MarkdownCache::RefreshWorker).to receive(:perform_async)
  end

  it 'enqueues the refreshes of a request once it has been handled' do
    app = ->(_env) do
      Gitlab::MarkdownCache::RefreshBatch.add(build_stubbed(:note, id: 1))
      expect(Gitlab::MarkdownCache::RefreshWorker).not_to have_received(:perform_async)

      [200, {}, ['OK']]
    end

    expect(described_class.new(app).call({})).to eq([200, {}, ['OK']])
    expect(Gitlab::MarkdownCache::RefreshWorker).to have_received(:perform_async).with('Note', [1])
  end

  it 'runs inside the request store' do
    middlewares = Rails.application.middleware.middlewares

    expect(middlewares.index(described_class)).to be > middlewares.index(RequestStore::Middleware)
  end
end
