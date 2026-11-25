# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Namespaces::UserNamespacePolicy, feature_category: :groups_and_projects do
  let_it_be(:user) { create(:user) }
  let_it_be(:owner) { create(:user) }
  let_it_be(:admin) { create(:admin) }
  let_it_be(:namespace) { create(:user_namespace, owner: owner) }

  let(:owner_permissions) do
    %i[
      create_projects create_project_fork import_projects admin_namespace update_runners_setting read_namespace
      read_namespace_via_membership read_statistics create_jira_connect_subscription admin_package read_billing
      edit_billing transfer_projects update_work_item_user_preference
    ]
  end

  let(:project_creation_permissions) { %i[create_projects import_projects transfer_projects] }

  subject { described_class.new(current_user, namespace) }

  context 'when the user is anonymous' do
    let(:current_user) { nil }

    it_behaves_like 'prevent all'
  end

  context 'when the user owns the namespace' do
    let(:current_user) { owner }

    it { expect_allowed(*owner_permissions) }

    context 'when the user cannot create personal projects' do
      before do
        allow(owner).to receive(:can_create_project?).and_return(false)
      end

      it { expect_disallowed(*project_creation_permissions) }
    end

    context 'when the namespace belongs to a bot' do
      let_it_be(:bot) { create(:user, :project_bot) }
      let_it_be(:namespace) { create(:user_namespace, owner: bot) }

      let(:current_user) { bot }

      before do
        allow(bot).to receive(:can_create_project?).and_return(true)
      end

      it { expect_disallowed(*project_creation_permissions) }
    end
  end

  context 'when the user does not own the namespace' do
    let(:current_user) { user }

    it { expect_disallowed(*owner_permissions) }
  end

  context 'when the user is an admin' do
    let(:current_user) { admin }

    context 'with admin mode enabled', :enable_admin_mode do
      it { expect_allowed(*owner_permissions) }
    end

    context 'without admin mode enabled' do
      it { expect_disallowed(*owner_permissions) }
    end
  end
end
