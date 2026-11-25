# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Ci::Runners::ResetRegistrationTokenService, '#execute', feature_category: :runner_core do
  subject(:execute) { described_class.new(scope, current_user).execute }

  let_it_be(:user) { build(:user) }
  let_it_be(:admin_user) { create(:user, :admin) }

  shared_examples 'a registration token reset operation' do
    context 'without user' do
      let(:current_user) { nil }

      it 'does not reset registration token and returns error response' do
        expect(scope).not_to receive(token_reset_method_name)

        expect(execute).to be_error
      end
    end

    context 'with unauthorized user' do
      let(:current_user) { user }

      it 'does not reset registration token and returns error response' do
        expect(scope).not_to receive(token_reset_method_name)

        expect(execute).to be_error
      end
    end

    context 'with admin user', :enable_admin_mode do
      let(:current_user) { admin_user }

      it 'resets registration token and returns value unchanged' do
        expect(scope).to receive(token_reset_method_name).once do
          expect(scope).to receive(token_method_name).once.and_return("#{token_method_name} return value")
        end

        expect(execute).to be_success
        expect(execute.payload[:new_registration_token]).to eq("#{token_method_name} return value")
      end

      context 'when allow_runner_registration_token is false' do
        before do
          stub_application_setting(allow_runner_registration_token: false)
        end

        it 'does not reset registration token and returns error response' do
          expect(scope).not_to receive(token_reset_method_name)

          expect(execute).to be_error
          expect(execute.message).to eq('user not allowed to update runners registration token')
        end
      end
    end
  end

  context 'with instance scope' do
    let_it_be(:scope) { create(:application_setting, allow_runner_registration_token: true) }

    before do
      allow(ApplicationSetting).to receive_messages(current: scope, current_without_cache: scope)
    end

    it_behaves_like 'a registration token reset operation' do
      let(:token_method_name) { :runners_registration_token }
      let(:token_reset_method_name) { :reset_runners_registration_token! }
    end
  end

  context 'with group scope' do
    let_it_be(:scope) { create(:group, :allow_runner_registration_token) }

    it_behaves_like 'a registration token reset operation' do
      let(:token_method_name) { :runners_token }
      let(:token_reset_method_name) { :reset_runners_token! }
    end
  end

  context 'with project scope' do
    let_it_be(:scope) { create(:project, :allow_runner_registration_token) }

    it_behaves_like 'a registration token reset operation' do
      let(:token_method_name) { :runners_token }
      let(:token_reset_method_name) { :reset_runners_token! }
    end
  end

  describe 'token format', :enable_admin_mode do
    include ::TokenAuthenticatableMatchers

    let(:current_user) { admin_user }
    let(:new_token) { execute.payload[:new_registration_token] }

    before do
      stub_config_cell({ enabled: true, id: 1 })
      # Keep the records saved in these examples from claiming against a Topology Service that isn't running.
      allow(Cells::TransactionRecord).to receive(:current_transaction).and_return(nil)
    end

    shared_examples 'a reset without a routing payload when the flag is disabled' do
      context 'when the routable_runner_registration_token feature flag is disabled' do
        before do
          stub_feature_flags(routable_runner_registration_token: false)
        end

        it 'resets the token to a token without a routing payload' do
          expect(new_token).to match(/\AGR1348941[\w-]{20}\z/)
        end
      end
    end

    context 'with group scope' do
      let_it_be_with_reload(:scope) { create(:group, :allow_runner_registration_token) }

      it 'resets the token to a routable token' do
        expect(new_token).to be_a_routable_token
          .with_payload("c:1\ng:#{scope.id.to_s(36)}\no:#{scope.organization_id.to_s(36)}")
      end

      it_behaves_like 'a reset without a routing payload when the flag is disabled'
    end

    context 'with project scope' do
      let_it_be_with_reload(:scope) { create(:project, :allow_runner_registration_token) }

      it 'resets the token to a routable token' do
        expect(new_token).to be_a_routable_token
          .with_payload("c:1\no:#{scope.organization_id.to_s(36)}\np:#{scope.id.to_s(36)}")
      end

      it_behaves_like 'a reset without a routing payload when the flag is disabled'
    end
  end
end
