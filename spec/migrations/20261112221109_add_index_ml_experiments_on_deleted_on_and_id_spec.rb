# frozen_string_literal: true

require 'spec_helper'
require_migration!

RSpec.describe AddIndexMlExperimentsOnDeletedOnAndId, feature_category: :mlops do
  let(:connection) { described_class.new.connection }

  def index
    connection.indexes(:ml_experiments).find { |index| index.name == described_class::INDEX_NAME }
  end

  it 'adds and removes the partial index' do
    reversible_migration do |migration|
      migration.before -> { expect(index).to be_nil }
      migration.after -> {
        expect(index).to have_attributes(columns: %w[deleted_on id], where: '(deleted_on IS NOT NULL)')
      }
    end
  end
end
