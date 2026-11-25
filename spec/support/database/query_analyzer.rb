# frozen_string_literal: true

# With the usage of `describe '...', query_analyzers: false`
# can be disabled selectively

module Database
  module SpecQueryAnalyzers
    def self.enabled
      [
        ::Gitlab::Database::QueryAnalyzers::PreventCrossDatabaseModification,
        ::Gitlab::Database::QueryAnalyzers::GitlabSchemasValidateConnection,
        ::Gitlab::Database::QueryAnalyzers::PreventSetOperatorMismatch,
        ::Database::PreventCrossJoins::Analyzer
      ]
    end

    # @note GitlabSchemasMetrics and LogLargeInLists only report. Capture and PreventWritesOnGet are
    #   disabled outside a request; their specs and the request middleware begin them.
    def self.skipped
      [
        ::Gitlab::Database::QueryAnalyzers::GitlabSchemasMetrics,
        ::Gitlab::Database::QueryAnalyzers::LogLargeInLists,
        ::Gitlab::Database::QueryAnalyzers::Capture,
        ::Gitlab::Database::QueryAnalyzers::PreventWritesOnGet
      ]
    end
  end
end

RSpec.configure do |config|
  config.before do |example|
    if example.metadata.fetch(:query_analyzers, true)
      ::Gitlab::Database::QueryAnalyzer.instance.begin!(::Database::SpecQueryAnalyzers.enabled)
    end
  end

  config.after do |example|
    if example.metadata.fetch(:query_analyzers, true)
      ::Gitlab::Database::QueryAnalyzer.instance.end!(::Database::SpecQueryAnalyzers.enabled)
    end
  end
end
