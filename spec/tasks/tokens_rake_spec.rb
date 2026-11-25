# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'tokens rake tasks', :silence_stdout, feature_category: :tooling do
  let!(:user) { create(:user) }

  before do
    Rake.application.rake_require 'tasks/tokens'
  end

  describe 'reset_all_email task' do
    it 'changes the incoming email token' do
      expect { run_rake_task('tokens:reset_all_email') }.to change { user.reload.incoming_email_token }
    end
  end

  describe 'reset_all_feed task' do
    it 'changes the feed token for the user' do
      expect { run_rake_task('tokens:reset_all_feed') }.to change { user.reload.feed_token }
    end

    context 'when the routable_feed_token feature flag is enabled for the user' do
      include ::TokenAuthenticatableMatchers
      include_context 'with token authenticatable routable token context'

      before do
        stub_feature_flags(routable_feed_token: user)
      end

      it 'resets the feed token to a routable token' do
        run_rake_task('tokens:reset_all_feed')

        expect(user.reload.feed_token).to eq(
          generate_routable_token(
            "c:1\no:#{user.organization_id.to_s(36)}\nu:#{user.id.to_s(36)}",
            random_bytes: random_bytes,
            prefix: User.prefix_for_feed_token
          )
        )
      end
    end

    context 'when the routable_feed_token feature flag is disabled' do
      include ::TokenAuthenticatableMatchers

      before do
        stub_feature_flags(routable_feed_token: false)
      end

      it 'resets the feed token to a non-routable token' do
        run_rake_task('tokens:reset_all_feed')

        expect(user.reload.feed_token).to start_with(User.prefix_for_feed_token)
        expect(user.feed_token).not_to be_a_routable_token
      end
    end

    context 'with configured instance prefix', :aggregate_failures do
      subject(:reset_all_feed_tokens) { run_rake_task('tokens:reset_all_feed') }

      let(:instance_prefix) { 'instanceprefix' }

      it 'includes the prefix after configuration has changed and task is run' do
        expect(user.feed_token).to start_with(User::FEED_TOKEN_PREFIX)
        stub_application_setting(instance_token_prefix: instance_prefix)
        reset_all_feed_tokens
        expect(user.reload.feed_token).to start_with(instance_prefix)
      end

      context 'with feature flag custom_prefix_for_all_token_types disabled' do
        before do
          stub_feature_flags(custom_prefix_for_all_token_types: false)
        end

        it 'does not include the prefix' do
          expect(user.feed_token).to start_with(User::FEED_TOKEN_PREFIX)
          stub_application_setting(instance_token_prefix: instance_prefix)
          reset_all_feed_tokens
          expect(user.reload.feed_token).to start_with(User::FEED_TOKEN_PREFIX)
        end
      end
    end
  end
end
