# frozen_string_literal: true

require 'fast_spec_helper'
require 'gitlab/rspec/all'

require_relative '../../../scripts/lib/assets_sha'

RSpec.describe AssetsSha, feature_category: :tooling do
  include StubENV

  describe '.assets_impacting_compilation' do
    it 'includes patch-package patches, which rewrite node_modules after install' do
      files = described_class.send(:assets_impacting_compilation)

      expect(files).to include(a_string_matching(%r{\Apatches/.+\.patch\z}))
    end

    it 'includes .browserslistrc, which sets the browsers the assets are compiled for' do
      files = described_class.send(:assets_impacting_compilation)

      expect(files).to include('.browserslistrc')
    end

    it 'includes Gemfile.next and Gemfile.next.lock, which affect gem-emitted assets' do
      files = described_class.send(:assets_impacting_compilation)

      expect(files).to include('Gemfile.next', 'Gemfile.next.lock')
    end

    it 'includes lib/tasks/gitlab/assets.rake, which controls asset compilation' do
      files = described_class.send(:assets_impacting_compilation)

      expect(files).to include('lib/tasks/gitlab/assets.rake')
    end

    it 'includes GraphQL queries imported through the shared_queries alias, which are compiled into the assets' do
      files = described_class.send(:assets_impacting_compilation)

      expect(files).to include('app/graphql/queries/pipelines/get_pipeline_details.query.graphql')
    end

    it 'excludes the MCP GraphQL queries, which are only read by Ruby' do
      files = described_class.send(:assets_impacting_compilation)

      expect(files).not_to include(a_string_starting_with('app/graphql/queries/mcp/'))
    end
  end

  describe '.sha256_of_assets_impacting_compilation' do
    before do
      allow(described_class).to receive(:assets_impacting_compilation).and_return([])
    end

    it 'returns a SHA256 hexdigest' do
      expect(described_class.sha256_of_assets_impacting_compilation).to match(/\A[0-9a-f]{64}\z/)
    end
  end
end
