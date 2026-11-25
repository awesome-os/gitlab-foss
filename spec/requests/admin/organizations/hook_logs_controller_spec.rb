# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Admin::Organizations::HookLogsController, :without_current_organization, feature_category: :webhooks do
  let_it_be(:organization) { create(:organization) }
  let_it_be(:other_organization) { create(:organization) }
  let_it_be(:admin) { create(:admin) }
  let_it_be(:organization_owner) { create(:user, :organization_owner, organization: organization) }
  let_it_be(:regular_user) { create(:user) }
  let_it_be_with_refind(:web_hook) { create(:system_hook, organization: organization) }
  let_it_be_with_refind(:web_hook_log) { create(:web_hook_log, web_hook: web_hook) }

  let(:show_path) { organization_admin_settings_hook_hook_log_path(organization, web_hook, web_hook_log) }
  let(:retry_path) { retry_organization_admin_settings_hook_hook_log_path(organization, web_hook, web_hook_log) }

  shared_examples 'a request gated by the org_admin_hooks feature flag' do
    before do
      sign_in(organization_owner)
      stub_feature_flags(org_admin_hooks: false)
    end

    it 'returns 404' do
      request

      expect(response).to have_gitlab_http_status(:not_found)
    end
  end

  shared_examples 'a request blocked on GitLab.com' do
    before do
      sign_in(organization_owner)
    end

    it 'returns 404', :saas do
      request

      expect(response).to have_gitlab_http_status(:not_found)
    end
  end

  shared_examples 'a request denied without the ability' do |ability|
    before do
      sign_in(organization_owner)
      allow(Ability).to receive(:allowed?).and_call_original
      allow(Ability).to receive(:allowed?).with(organization_owner, ability, anything).and_return(false)
    end

    it 'returns 404' do
      request

      expect(response).to have_gitlab_http_status(:not_found)
    end
  end

  shared_examples 'a request denied to users outside the organization admin area' do
    before do
      sign_in(regular_user)
    end

    it 'returns 404' do
      request

      expect(response).to have_gitlab_http_status(:not_found)
    end
  end

  context 'when user is an organization owner' do
    let(:user) { organization_owner }

    it_behaves_like 'web hook log actions' do
      let!(:show_path) { organization_admin_settings_hook_hook_log_path(organization, web_hook, web_hook_log) }
      let!(:retry_path) { retry_organization_admin_settings_hook_hook_log_path(organization, web_hook, web_hook_log) }
      let(:edit_hook_path) { edit_organization_admin_settings_hook_path(organization, web_hook) }
    end
  end

  describe 'requests for the default organization' do
    let_it_be(:default_organization) { create(:organization, :default) } # rubocop:disable Gitlab/RSpec/AvoidCreateDefaultOrganization -- Default organization org-level hooks are only managed by instance admin in /admin/hooks
    let_it_be(:default_organization_owner) do
      create(:user, :organization_owner, organization: default_organization)
    end

    let_it_be(:default_hook) { create(:system_hook, organization: default_organization) }
    let_it_be(:default_hook_log) { create(:web_hook_log, web_hook: default_hook) }

    let(:default_show_path) do
      organization_admin_settings_hook_hook_log_path(default_organization, default_hook, default_hook_log)
    end

    let(:default_retry_path) do
      retry_organization_admin_settings_hook_hook_log_path(default_organization, default_hook, default_hook_log)
    end

    context 'when user is an owner of the default organization' do
      before do
        sign_in(default_organization_owner)
      end

      it 'returns 404 for show' do
        get default_show_path

        expect(response).to have_gitlab_http_status(:not_found)
      end

      it 'returns 404 for retry and does not execute the hook', :aggregate_failures do
        expect(WebHooks::Events::ResendService).not_to receive(:new)

        post default_retry_path

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context 'when user is an instance admin', :enable_admin_mode do
      before do
        sign_in(admin)
      end

      it 'returns 404 for show' do
        get default_show_path

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end
  end

  describe 'GET /o/:organization_path/admin/settings/hooks/:hook_id/hook_logs/:id' do
    subject(:request) { get show_path }

    let(:other_organization_request) do
      get organization_admin_settings_hook_hook_log_path(other_organization, web_hook, web_hook_log)
    end

    it_behaves_like 'an organization admin area request'
    it_behaves_like 'a request gated by the org_admin_hooks feature flag'
    it_behaves_like 'a request blocked on GitLab.com'
    it_behaves_like 'a request denied without the ability', :read_webhook_event

    context 'when user is an organization owner' do
      before do
        sign_in(organization_owner)
      end

      it 'renders the resend button with the organization-scoped retry path', :aggregate_failures do
        request

        expect(response).to have_gitlab_http_status(:ok)
        expect(response.body).to include(retry_path)
        expect(response.body).not_to include('/admin/hooks')
      end

      it_behaves_like 'system hook lookup scoped to the organization' do
        def request_system_hook(hook)
          get organization_admin_settings_hook_hook_log_path(
            organization, hook, create(:web_hook_log, web_hook_id: hook.id)
          )
        end
      end
    end
  end

  describe 'POST /o/:organization_path/admin/settings/hooks/:hook_id/hook_logs/:id/retry' do
    subject(:request) { post retry_path }

    it_behaves_like 'a request gated by the org_admin_hooks feature flag'
    it_behaves_like 'a request blocked on GitLab.com'
    it_behaves_like 'a request denied without the ability', :resend_webhook_event
    it_behaves_like 'a request denied to users outside the organization admin area'

    context 'when user is an organization owner' do
      before do
        sign_in(organization_owner)
      end

      it_behaves_like 'system hook lookup scoped to the organization' do
        def request_system_hook(hook)
          post retry_organization_admin_settings_hook_hook_log_path(
            organization, hook, create(:web_hook_log, web_hook_id: hook.id)
          )
        end
      end
    end
  end
end
