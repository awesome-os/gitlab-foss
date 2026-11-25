# frozen_string_literal: true

require 'spec_helper'
require_migration!

RSpec.describe RemoveFinalizedIndexFromAnalyticsDevopsAdoptionSnapshots, feature_category: :devops_reports do
  let(:migration) { described_class.new }

  describe '#up / #down' do
    it 'drops and recreates the partial index' do
      reversible_migration do |m|
        m.before -> {
          expect(migration.index_exists_by_name?(described_class::TABLE_NAME, described_class::INDEX_NAME)).to be(true)
        }

        m.after -> {
          expect(migration.index_exists_by_name?(described_class::TABLE_NAME, described_class::INDEX_NAME)).to be(false)
        }
      end
    end
  end
end
