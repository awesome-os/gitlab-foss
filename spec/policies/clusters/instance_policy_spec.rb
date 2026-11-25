# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Clusters::InstancePolicy, feature_category: :deployment_management do
  let(:user) { build_stubbed(:user) }
  let(:permissions) { %i[read_cluster add_cluster create_cluster update_cluster admin_cluster read_prometheus] }

  subject(:policy) { described_class.new(user, Clusters::Instance.new) }

  context 'when the user is not an admin' do
    it { expect_disallowed(*permissions) }
  end

  context 'when the user is an admin' do
    let(:user) { build_stubbed(:admin) }

    context 'with admin mode enabled', :enable_admin_mode do
      it { expect_allowed(*permissions) }
    end

    context 'without admin mode enabled' do
      it { expect_disallowed(*permissions) }
    end
  end
end
