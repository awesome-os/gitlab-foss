# frozen_string_literal: true

require 'spec_helper'

RSpec.describe MetricsController, feature_category: :scalability do
  it_behaves_like 'Base action controller' do
    subject(:request) { get metrics_path }
  end
end
