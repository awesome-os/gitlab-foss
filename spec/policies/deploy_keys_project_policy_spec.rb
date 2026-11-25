# frozen_string_literal: true

require 'spec_helper'

RSpec.describe DeployKeysProjectPolicy, feature_category: :continuous_delivery do
  let_it_be(:project) { create(:project) }
  let_it_be(:maintainer) { create(:user, maintainer_of: project) }
  let_it_be(:public_key) do
    create(:deploy_keys_project, project: project, deploy_key: create(:deploy_key, public: true))
  end

  let_it_be(:private_key) do
    create(:deploy_keys_project, project: project, deploy_key: create(:deploy_key, public: false))
  end

  subject(:policy) { described_class.new(maintainer, deploy_keys_project) }

  it { expect(described_class).to delegate_to(ProjectPolicy) }

  describe 'update_deploy_keys_project' do
    context 'when the deploy key is public' do
      let(:deploy_keys_project) { public_key }

      it { expect_allowed(:update_deploy_keys_project) }

      context 'when the user cannot admin_project' do
        before do
          stub_permissions(admin_project: false)
        end

        it { expect_disallowed(:update_deploy_keys_project) }
      end
    end

    context 'when the deploy key is private' do
      let(:deploy_keys_project) { private_key }

      it { expect_disallowed(:update_deploy_keys_project) }
    end
  end
end
