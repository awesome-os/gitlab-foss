# frozen_string_literal: true

require 'spec_helper'

RSpec.describe NamespaceSerializer, feature_category: :groups_and_projects do
  it 'represents NamespaceBasicEntity entities' do
    expect(described_class.entity_class).to eq(NamespaceBasicEntity)
  end
end
