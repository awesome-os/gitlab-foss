# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Clusters::ClusterEnabledGrant, feature_category: :deployment_management do
  it { is_expected.to belong_to :namespace }
end
