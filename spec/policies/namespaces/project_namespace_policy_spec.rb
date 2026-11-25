# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Namespaces::ProjectNamespacePolicy, feature_category: :groups_and_projects do
  include ExternalAuthorizationServiceHelpers
  include AdminModeHelper

  let_it_be(:public_project) { create(:project, :public) }
  let_it_be(:private_project) { create(:project, :private) }

  subject { described_class.new(current_user, namespace) }

  it { expect(described_class.new(nil, public_project.project_namespace)).to delegate_to(ProjectPolicy) }

  it_behaves_like 'checks timelog categories permissions' do
    let(:project) { create(:project) }
    let(:namespace) { project.project_namespace }
    let(:users_container) { project }
  end

  context 'with read_namespace permissions' do
    let_it_be(:project) { public_project }
    let(:owner) { project.creator }
    let_it_be(:developer) { create(:user) }
    let_it_be(:admin) { create(:admin) }
    let(:namespace) { project.project_namespace }

    before_all do
      project.add_developer(developer)
    end

    context 'when a user has read access to the project' do
      where(:user_role) do
        %i[owner developer admin]
      end

      with_them do
        let(:current_user) { public_send(user_role) }

        it { expect_allowed(:read_project, :read_namespace) }
      end
    end

    context 'when the user is the owner' do
      let(:current_user) { owner }

      it 'never checks the external service' do
        expect(::Gitlab::ExternalAuthorization).not_to receive(:access_allowed?)

        expect_allowed(:read_project, :read_namespace)
      end
    end

    context 'with an external authorization service' do
      before do
        enable_external_authorization_service_check
      end

      context 'when the external service allows access' do
        where(:user_role) do
          %i[owner developer]
        end

        with_them do
          let(:current_user) { public_send(user_role) }

          it 'allows access' do
            external_service_allow_access(current_user, project)

            expect_allowed(:read_project, :read_namespace)
          end
        end
      end

      context 'with an admin' do
        let(:current_user) { admin }

        context 'when admin mode is enabled', :enable_admin_mode do
          it 'does not check the external service and allows access' do
            expect(::Gitlab::ExternalAuthorization).not_to receive(:access_allowed?)

            expect_allowed(:read_project, :read_namespace)
          end
        end

        context 'when admin mode is disabled' do
          it 'checks the external service and allows access' do
            external_service_allow_access(admin, project)

            expect(::Gitlab::ExternalAuthorization).to receive(:access_allowed?)

            expect_allowed(:read_project, :read_namespace)
          end
        end
      end

      context 'when the external service denies access' do
        where(:user_role) do
          %i[developer owner other_user anonymous]
        end

        with_them do
          let(:other_user) { build(:user) }
          let(:anonymous) { nil }
          let(:current_user) { public_send(user_role) }

          it 'prevents all but seeing a public project in a list' do
            external_service_deny_access(current_user, project)

            expect_disallowed(:read_project, :read_namespace)
          end
        end
      end

      it 'passes the full path to external authorization for logging purposes' do
        expect(::Gitlab::ExternalAuthorization)
          .to receive(:access_allowed?).with(owner, 'default_label', project.full_path).and_call_original

        described_class.new(owner, namespace).allowed?(:read_project, :read_namespace)
      end
    end

    context 'with support bot user' do
      let_it_be(:current_user) { create(:support_bot) }

      context 'with service desk disabled' do
        it { expect_disallowed(:read_project, :read_namespace) }
      end
    end

    context 'with deploy key access actor' do
      context 'when project is private' do
        let(:project) { private_project }
        let(:deploy_key) { create(:deploy_key, user: owner) }

        subject { described_class.new(deploy_key, project.project_namespace) }

        context 'when a read deploy key is enabled in the project' do
          let!(:deploy_keys_project) { create(:deploy_keys_project, project: project, deploy_key: deploy_key) }

          it { expect_disallowed(:read_project, :read_namespace) }
        end

        context 'when a write deploy key is enabled in the project' do
          let!(:deploy_keys_project) do
            create(:deploy_keys_project, :write_access, project: project, deploy_key: deploy_key)
          end

          it { expect_disallowed(:read_project, :read_namespace) }
        end

        context 'when the deploy key is not enabled in the project' do
          it { expect_disallowed(:read_project, :read_namespace) }
        end
      end
    end
  end

  describe 'read_namespace_via_membership' do
    using RSpec::Parameterized::TableSyntax

    let_it_be(:internal_project) { create(:project, :internal) }
    let_it_be(:non_member) { create(:user) }
    let_it_be(:guest) { create(:user, guest_of: [public_project, internal_project]) }
    let_it_be(:admin) { create(:admin) }

    subject(:policy) { described_class.new(current_user, project.project_namespace) }

    where(:project, :current_user, :admin_mode, :allowed) do
      ref(:public_project)   | ref(:non_member) | false | false
      ref(:internal_project) | ref(:non_member) | false | false
      ref(:public_project)   | ref(:guest)      | false | true
      ref(:internal_project) | ref(:guest)      | false | true
      ref(:public_project)   | ref(:admin)      | false | false
      ref(:public_project)   | ref(:admin)      | true  | true
    end

    with_them do
      before do
        enable_admin_mode!(admin) if admin_mode
      end

      it { expect(policy.allowed?(:read_namespace_via_membership)).to eq(allowed) }
    end
  end
end
