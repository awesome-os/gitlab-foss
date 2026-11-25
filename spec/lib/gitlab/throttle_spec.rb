# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Throttle do
  using RSpec::Parameterized::TableSyntax

  describe '.protected_paths_enabled?' do
    subject { described_class.protected_paths_enabled? }

    it 'returns Application Settings throttle_protected_paths_enabled?' do
      expect(Gitlab::CurrentSettings.current_application_settings).to receive(:throttle_protected_paths_enabled?)

      subject
    end
  end

  describe '.bypass_header' do
    subject { described_class.bypass_header }

    it 'is nil' do
      expect(subject).to be_nil
    end

    context 'when a header is configured' do
      before do
        stub_env('GITLAB_THROTTLE_BYPASS_HEADER', 'My-Custom-Header')
      end

      it 'is a funny upper case rack key' do
        expect(subject).to eq('HTTP_MY_CUSTOM_HEADER')
      end
    end
  end

  describe '.rate_limiting_response_text' do
    subject { described_class.rate_limiting_response_text }

    context 'when the setting is not present' do
      before do
        stub_application_setting(rate_limiting_response_text: '')
      end

      it 'returns the default value with a trailing newline' do
        expect(subject).to eq(described_class::DEFAULT_RATE_LIMITING_RESPONSE_TEXT + "\n")
      end
    end

    context 'when the setting is present' do
      let(:response_text) do
        'Rate limit exceeded; see https://docs.gitlab.com/user/gitlab_com/rate_limits/ for more details'
      end

      before do
        stub_application_setting(rate_limiting_response_text: response_text)
      end

      it 'returns the default value with a trailing newline' do
        expect(subject).to eq(response_text + "\n")
      end
    end
  end

  describe '.throttle_authenticated_git_http_options' do
    before do
      stub_application_setting(
        throttle_authenticated_git_http_requests_per_period: 50,
        throttle_authenticated_git_http_period_in_seconds: 30
      )
    end

    it 'returns correct options' do
      options = described_class.throttle_authenticated_git_http_options

      expect(options[:limit].call).to eq(50)
      expect(options[:period].call).to eq(30)
    end
  end

  describe '.throttle_authenticated_mcp_options', feature_category: :rate_limiting do
    before do
      stub_application_setting(
        throttle_authenticated_mcp_requests_per_period: 50,
        throttle_authenticated_mcp_period_in_seconds: 30
      )
    end

    it 'returns correct options' do
      options = described_class.throttle_authenticated_mcp_options

      expect(options[:limit].call).to eq(50)
      expect(options[:period].call).to eq(30)
    end
  end

  describe '.throttle_authenticated_dependency_proxy_options' do
    before do
      stub_application_setting(
        throttle_authenticated_dependency_proxy_requests_per_period: 50,
        throttle_authenticated_dependency_proxy_period_in_seconds: 30
      )
    end

    it 'returns correct options' do
      options = described_class.throttle_authenticated_dependency_proxy_options

      expect(options[:limit].call).to eq(50)
      expect(options[:period].call).to eq(30)
    end
  end

  describe 'the per-project Git throttle options', feature_category: :rate_limiting do
    let_it_be(:project, refind: true) { create(:project) }

    let(:instance_limit) { 600 }

    # What Labkit hands a limit callable: the request's facts, where the rule that
    # matched has already resolved the override key.
    def facts(fact, key)
      { fact => key }
    end

    after do
      Gitlab::RateLimit::ProjectThrottleLimits.expire!
    end

    where(:options_method, :fact, :column) do
      [
        [:throttle_unauthenticated_git_http_project_options, :unauthenticated_git_http_project,
          :throttle_unauthenticated_git_http_requests_per_period],
        [:throttle_authenticated_git_http_project_options, :authenticated_git_http_project,
          :throttle_authenticated_git_http_requests_per_period],
        [:throttle_authenticated_git_lfs_project_options, :authenticated_git_lfs_project,
          :throttle_authenticated_git_lfs_requests_per_period]
      ]
    end

    with_them do
      subject(:limit) { described_class.public_send(options_method)[:limit] }

      before do
        stub_application_setting(column => instance_limit)
        Gitlab::RateLimit::ProjectThrottleLimits.expire!
      end

      it 'resolves the project override when the fact carries its key' do
        project.project_setting.update!(column => 5)
        Gitlab::RateLimit::ProjectThrottleLimits.expire!

        expect(limit.call(facts(fact, project.full_path.downcase))).to eq(5)
      end

      it 'clamps an override above the instance limit' do
        project.project_setting.update!(column => instance_limit + 100)
        Gitlab::RateLimit::ProjectThrottleLimits.expire!

        expect(limit.call(facts(fact, project.full_path.downcase))).to eq(instance_limit)
      end

      it 'falls back to the instance limit when the fact is nil' do
        expect(limit.call(facts(fact, nil))).to eq(instance_limit)
      end

      # Labkit resolves a zero-arity callable without a context; a proc binds nil,
      # and that must not activate an override.
      it 'falls back to the instance limit without a context' do
        expect(limit.call(nil)).to eq(instance_limit)
      end
    end
  end
end
