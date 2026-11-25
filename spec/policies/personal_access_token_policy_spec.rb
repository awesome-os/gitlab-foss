# frozen_string_literal: true

require 'spec_helper'

RSpec.describe PersonalAccessTokenPolicy, feature_category: :system_access do
  include AdminModeHelper

  subject { described_class.new(current_user, token) }

  context 'when the current user is an administrator' do
    let_it_be(:current_user) { build_stubbed(:admin) }
    let_it_be(:token) { build_stubbed(:personal_access_token) }

    context 'with admin mode enabled', :enable_admin_mode do
      it { expect_allowed(:revoke_personal_access_token) }
    end

    context 'without admin mode enabled' do
      it { expect_disallowed(:revoke_personal_access_token) }
    end
  end

  context 'when the current user is not an administrator' do
    let_it_be(:current_user) { build_stubbed(:user) }

    context 'when the user does not own the token' do
      let_it_be(:token) { build_stubbed(:personal_access_token) }

      it { expect_disallowed(:revoke_personal_access_token) }
    end

    context 'when the user owns the token' do
      let_it_be(:token) { build_stubbed(:personal_access_token, user: current_user) }

      it { expect_allowed(:revoke_personal_access_token) }
    end

    context 'when the token is an impersonation token for the user' do
      let_it_be(:token) { build_stubbed(:personal_access_token, user: current_user, impersonation: true) }

      it { expect_disallowed(:revoke_personal_access_token) }
    end
  end

  context 'when the current user is a blocked administrator', :enable_admin_mode do
    let_it_be(:current_user) { create(:admin, :blocked) }

    context 'when the user owns the token' do
      let_it_be(:token) { build_stubbed(:personal_access_token, user: current_user) }

      it { expect_disallowed(:revoke_personal_access_token) }
    end

    context 'when the user does not own the token' do
      let_it_be(:token) { build_stubbed(:personal_access_token) }

      it { expect_disallowed(:revoke_personal_access_token) }
    end
  end

  context "with a service account's token", feature_category: :user_management do
    let_it_be(:group) { create(:group) }
    let_it_be(:project) { create(:project, group: group) }

    shared_examples 'follows admin_service_accounts on the provisioning scope' do
      context 'when the actor owns the provisioning scope' do
        before do
          scope_owner.add_owner(current_user)
        end

        it { expect_allowed(:revoke_personal_access_token) }

        context 'when the actor is blocked' do
          let(:current_user) { create(:user, :blocked) }

          it { expect_disallowed(:revoke_personal_access_token) }
        end
      end

      context 'when the actor is not a member of the provisioning scope' do
        it { expect_disallowed(:revoke_personal_access_token) }
      end
    end

    context 'when the service account is group-provisioned' do
      let_it_be(:service_account) { create(:user, :service_account, provisioned_by_group: group) }
      let_it_be(:token) { create(:personal_access_token, user: service_account) }
      let(:current_user) { create(:user) }
      let(:scope_owner) { group }

      it_behaves_like 'follows admin_service_accounts on the provisioning scope'

      context 'when the actor is a group maintainer (no admin_service_accounts at group level)' do
        let_it_be(:maintainer) { create(:user) }
        let(:current_user) { maintainer }

        before_all do
          group.add_maintainer(maintainer)
        end

        it { expect_disallowed(:revoke_personal_access_token) }
      end
    end

    context 'when the service account is project-provisioned' do
      let_it_be(:service_account) { create(:user, :service_account, provisioned_by_project: project) }
      let_it_be(:token) { create(:personal_access_token, user: service_account) }
      let(:current_user) { create(:user) }
      let(:scope_owner) { project }

      it_behaves_like 'follows admin_service_accounts on the provisioning scope'

      context 'when the actor is a project maintainer (has admin_service_accounts at project level)' do
        let_it_be(:maintainer) { create(:user) }
        let(:current_user) { maintainer }

        before_all do
          project.add_maintainer(maintainer)
        end

        it { expect_allowed(:revoke_personal_access_token) }
      end
    end

    context 'when the service account has no provisioning scope' do
      let_it_be(:service_account) { create(:user, :service_account) }
      let_it_be(:token) { create(:personal_access_token, user: service_account) }
      let(:current_user) { create(:user) }

      it { expect_disallowed(:revoke_personal_access_token) }
    end
  end
end
