# frozen_string_literal: true

require 'spec_helper'

RSpec.describe DeployKeyPolicy, feature_category: :groups_and_projects do
  subject { described_class.new(current_user, deploy_key) }

  let_it_be_with_refind(:current_user) { create(:user) }
  let_it_be(:admin) { create(:user, :admin) }

  let(:read_permissions) { %i[read_deploy_key enable_deploy_key] }
  let(:update_permissions) { %i[update_deploy_key update_deploy_key_title] }
  let(:all_permissions) { read_permissions + update_permissions }

  context 'when deploy key is public' do
    let_it_be(:deploy_key) { create(:deploy_key, public: true) }

    context 'and current_user is nil' do
      let(:current_user) { nil }

      it { expect_disallowed(*all_permissions) }
    end

    context 'and current_user is present' do
      it { expect_allowed(*read_permissions) }
      it { expect_disallowed(*update_permissions) }
    end

    context 'when current_user is admin' do
      let(:current_user) { admin }

      context 'when admin mode enabled', :enable_admin_mode do
        it { expect_allowed(*all_permissions) }
      end

      context 'when admin mode disabled' do
        it { expect_allowed(*read_permissions) }
        it { expect_disallowed(*update_permissions) }
      end
    end
  end

  context 'when deploy key is private' do
    let_it_be(:deploy_key) { create(:deploy_key, :private) }

    context 'and current_user is nil' do
      let(:current_user) { nil }

      it { expect_disallowed(*all_permissions) }
    end

    context 'when current_user is admin' do
      let(:current_user) { admin }

      context 'when admin mode enabled', :enable_admin_mode do
        it { expect_allowed(*all_permissions) }
      end

      context 'when admin mode disabled' do
        it { expect_disallowed(*all_permissions) }
      end
    end

    context 'when the key is not assigned to any project' do
      before do
        stub_permissions(update_deploy_key: true)
      end

      it { expect_allowed(:update_deploy_key_title) }
    end

    context 'when assigned to the project' do
      let_it_be(:deploy_keys_project) { create(:deploy_keys_project, deploy_key: deploy_key) }

      before_all do
        deploy_keys_project.project.add_maintainer(current_user)
      end

      it { expect_allowed(*all_permissions) }
    end

    context 'when the user has no project with the key' do
      it { expect_disallowed(*all_permissions) }
    end

    context 'when assigned to multiple projects' do
      let_it_be(:project_one) { create(:project) }
      let_it_be(:project_two) { create(:project) }

      before_all do
        create(:deploy_keys_project, project: project_one, deploy_key: deploy_key)
        create(:deploy_keys_project, project: project_two, deploy_key: deploy_key)

        project_one.add_maintainer(current_user)
      end

      it { expect_allowed(*read_permissions, :update_deploy_key) }
      it { expect_disallowed(:update_deploy_key_title) }

      context 'when current_user is admin', :enable_admin_mode do
        let(:current_user) { admin }

        it { expect_allowed(:update_deploy_key_title) }
      end
    end
  end
end
