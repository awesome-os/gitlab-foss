# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ApplicationSettingPolicy, feature_category: :settings do
  let_it_be(:user) { create(:user) }
  let_it_be(:admin) { create(:admin) }

  let(:current_user) { user }
  let(:allow_runner_registration_token) { true }
  let(:token_permissions) { %i[read_runners_registration_token update_runners_registration_token] }

  subject(:policy) { described_class.new(current_user, [user]) }

  before do
    stub_application_setting(allow_runner_registration_token: allow_runner_registration_token)
  end

  context 'when the user is an admin' do
    let(:current_user) { admin }

    context 'with admin mode enabled', :enable_admin_mode do
      it { expect_allowed(:read_application_setting, *token_permissions) }

      context 'when runner registration tokens are disabled' do
        let(:allow_runner_registration_token) { false }

        it { expect_allowed(:read_application_setting) }
        it { expect_disallowed(*token_permissions) }
      end
    end

    context 'without admin mode enabled' do
      it { expect_disallowed(:read_application_setting, *token_permissions) }
    end
  end

  context 'when the user is not an admin' do
    it { expect_disallowed(:read_application_setting, *token_permissions) }
  end
end
