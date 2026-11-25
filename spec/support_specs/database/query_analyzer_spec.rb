# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Database::SpecQueryAnalyzers', feature_category: :database do
  let(:all_analyzers) { Gitlab::Database::QueryAnalyzer.instance.all_analyzers }
  let(:enabled) { Database::SpecQueryAnalyzers.enabled }
  let(:skipped) { Database::SpecQueryAnalyzers.skipped }

  it 'lists every registered analyzer as enabled or skipped' do
    expect(enabled + skipped).to match_array(all_analyzers), -> do
      'A query analyzer was added to or removed from `all_analyzers`. Add it to `enabled` or `skipped` ' \
        'in spec/support/database/query_analyzer.rb, depending on whether specs should begin it.'
    end
  end

  it 'does not list an analyzer as both enabled and skipped' do
    expect(enabled & skipped).to be_empty
  end
end
