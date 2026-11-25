# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'gitlab:mobile_push rake tasks', :silence_stdout, feature_category: :notifications do
  before(:all) do
    Rake.application.rake_require 'tasks/gitlab/mobile_push'
  end

  describe ':clear_content_keys' do
    let(:user) { create(:user) }
    let(:other_user) { create(:user) }

    let(:key) { Base64.strict_encode64(SecureRandom.random_bytes(32)) }

    let!(:subscription) { create(:mobile_device_push_subscription, user: user, content_key: key) }
    let!(:other_subscription) { create(:mobile_device_push_subscription, user: other_user, content_key: key) }

    it 'clears every stored key' do
      expect { run_rake_task('gitlab:mobile_push:clear_content_keys') }
        .to output("Cleared the content key of 2 push subscription(s).\n").to_stdout

      expect(subscription.reload.content_key).to be_nil
      expect(other_subscription.reload.content_key).to be_nil
    end

    it "clears one user's keys when given a username" do
      expect { run_rake_task('gitlab:mobile_push:clear_content_keys', user.username) }
        .to output("Cleared the content key of 1 push subscription(s).\n").to_stdout

      expect(subscription.reload.content_key).to be_nil
      expect(other_subscription.reload.content_key).to eq(key)
    end

    it 'aborts for an unknown username' do
      expect { run_rake_task('gitlab:mobile_push:clear_content_keys', 'nobody-here') }
        .to raise_error(SystemExit, /Unable to find user with username nobody-here/)

      expect(subscription.reload.content_key).to eq(key)
    end
  end
end
