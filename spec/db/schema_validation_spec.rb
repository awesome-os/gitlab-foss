# frozen_string_literal: true

require 'spec_helper'

# The test database is built from db/structure.sql, so any inconsistency the gem reports here is a gem defect.
RSpec.describe 'Schema validation of db/structure.sql against the test database', feature_category: :database do
  let(:connection) { ApplicationRecord.connection }
  let(:structure_sql_path) { Rails.root.join('db/structure.sql') }
  let(:structure_sql) do
    Gitlab::Schema::Validation::Sources::StructureSql.new(structure_sql_path, connection.current_schema)
  end

  let(:database) { Gitlab::Schema::Validation::Sources::Database.new(connection) }
  let(:validators) { Gitlab::Schema::Validation::Validators::Base.all_validators }

  it 'reports no inconsistency' do
    inconsistencies = Gitlab::Schema::Validation::Runner.new(structure_sql, database, validators: validators).execute
      .filter_map(&Gitlab::Database::SchemaValidation::InconsistencyFilter.new)

    # RSpec truncates the inspected array, so list every message in the failure instead
    expect(inconsistencies).to be_empty, -> { inconsistencies.map(&:error_message).join("\n") }
  end
end
