# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['WikiPageVersion'], feature_category: :wiki do
  specify { expect(described_class.graphql_name).to eq('WikiPageVersion') }

  it 'has the correct fields' do
    expect(described_class).to have_graphql_fields(:sha, :author_name, :message, :authored_date)
  end

  it 'uses a countable connection' do
    expect(described_class.connection_type).to have_graphql_fields(:count).at_least
  end
end
