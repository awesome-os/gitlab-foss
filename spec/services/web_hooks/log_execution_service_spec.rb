# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WebHooks::LogExecutionService, feature_category: :webhooks do
  include ExclusiveLeaseHelpers
  using RSpec::Parameterized::TableSyntax

  describe '#execute', :freeze_time do
    let_it_be_with_reload(:project_hook) { create(:project_hook) }

    let(:idempotency_key) { SecureRandom.uuid }
    let(:response_category) { :ok }
    let(:request_headers) { { 'Header' => 'header value', 'Idempotency-Key' => idempotency_key } }
    let(:data) do
      {
        trigger: 'trigger_name',
        url: 'https://example.com',
        request_headers: request_headers,
        request_data: { 'Request Data' => 'request data value' },
        response_body: 'Response body',
        response_status: '200',
        execution_duration: 1.2,
        internal_error_message: 'error message'
      }
    end

    subject(:service) { described_class.new(hook: project_hook, log_data: data, response_category: response_category) }

    it 'logs the data' do
      expect { service.execute }.to change { ::WebHookLog.count }.by(1)

      expect(WebHookLog.recent.first).to have_attributes(
        data.merge(project_id: project_hook.project_id, group_id: nil, organization_id: nil)
      )
    end

    it 'logs the data without opening a transaction' do
      allow(WebHookLog.connection).to receive(:transaction).and_call_original

      expect { service.execute }.to change { ::WebHookLog.count }.by(1)

      expect(WebHookLog.connection).not_to have_received(:transaction)
    end

    context 'when data contains unsafe YAML properties' do
      before do
        data[:request_data] = { data: described_class }
      end

      it 'casts to safe properties and logs the data' do
        expect { service.execute }.to change { ::WebHookLog.count }.by(1)

        expect(WebHookLog.recent.first).to have_attributes('request_data' => { 'data' => described_class.to_s })
      end
    end

    context 'obtaining an exclusive lease' do
      let(:lease_key) { "web_hooks:update_hook_failure_state:#{project_hook.id}" }
      let(:response_category) { :error }

      it 'updates failure state using a lease that ensures fresh state is written' do
        lease = stub_exclusive_lease(lease_key, timeout: described_class::LOCK_TTL)
        parent = project_hook.parent
        allow(project_hook).to receive(:parent).and_return(parent)

        expect(lease).to receive(:try_obtain)
        expect(lease).to receive(:cancel)
        expect(parent).to receive(:update_last_webhook_failure).with(project_hook)
        expect { service.execute }.to change { WebHook.find(project_hook.id).recent_failures }.to(1)
      end

      context 'when response_category is :ok' do
        let(:response_category) { :ok }

        it 'does not try to obtain a lease and updates the last failure' do
          parent = project_hook.parent
          allow(project_hook).to receive(:parent).and_return(parent)

          expect(Gitlab::ExclusiveLease).not_to receive(:new)
          expect(parent).to receive(:update_last_webhook_failure).with(project_hook)

          service.execute
        end

        context 'when the hook had previously failed but was loaded from a stale replica' do
          where(:recent_failures, :disabled_until) do
            2 | nil
            0 | 1.hour.from_now
          end

          with_them do
            before do
              project_hook.update!(recent_failures: recent_failures, disabled_until: disabled_until)
              project_hook.assign_attributes(recent_failures: 0, disabled_until: nil)
            end

            it 'reads the hook from the primary and resets failure state using a lease' do
              lb_session = ::Gitlab::Database::LoadBalancing::SessionMap.current(project_hook.load_balancer)
              allow(::Gitlab::Database::LoadBalancing::SessionMap).to receive(:current).and_call_original
              allow(::Gitlab::Database::LoadBalancing::SessionMap)
                .to receive(:current).with(project_hook.load_balancer).and_return(lb_session)
              lease = stub_exclusive_lease(lease_key, timeout: described_class::LOCK_TTL)

              expect(lb_session).to receive(:use_primary).and_call_original
              expect(lease).to receive(:try_obtain)
              expect(lease).to receive(:cancel)
              expect { service.execute }.to change { WebHook.find(project_hook.id).attributes.values_at('recent_failures', 'disabled_until') }.to([0, nil])
            end
          end
        end
      end

      context 'when the hook does not have auto-disabling enabled' do
        before do
          allow(project_hook).to receive(:auto_disabling_enabled?).and_return(false)
        end

        it 'does not try to obtain a lease or update failure state' do
          lease = stub_exclusive_lease(lease_key, timeout: described_class::LOCK_TTL)

          expect(lease).not_to receive(:try_obtain)
          expect { service.execute }.not_to change { WebHook.find(project_hook.id).recent_failures }.from(0)
        end
      end

      context 'when a lease cannot be obtained' do
        before do
          stub_exclusive_lease_taken(lease_key)
        end

        it 'creates the WebHookLog and skips hook state update' do
          expect(project_hook).not_to receive(:backoff!)
          expect(project_hook).not_to receive(:parent)

          expect { service.execute }.to change { ::WebHookLog.count }.by(1)
        end
      end
    end

    context 'when response_category is :ok' do
      it 'does not increment the failure count' do
        expect { service.execute }.not_to change { project_hook.recent_failures }
      end

      it 'does not change the disabled_until attribute' do
        expect { service.execute }.not_to change { project_hook.disabled_until }
      end

      context 'when the hook had previously failed' do
        before do
          project_hook.update!(recent_failures: 2)
        end

        it 'resets the failure count' do
          expect { service.execute }.to change { project_hook.recent_failures }.to(0)
        end
      end
    end

    context 'when response_category is :error' do
      let(:response_category) { :error }

      before do
        data[:response_status] = '500'
      end

      it 'backs off' do
        expect(project_hook).to receive(:backoff!)

        service.execute
      end
    end

    context 'with a system hook' do
      let(:response_category) { :error }

      subject(:service) { described_class.new(hook: system_hook, log_data: data, response_category: response_category) }

      context 'when the hook is in a non-default organization' do
        let_it_be(:organization) { create(:organization) }
        let_it_be_with_reload(:system_hook) { create(:system_hook, organization: organization) }

        it 'backs off the hook without tracking an error' do
          expect(Gitlab::ErrorTracking).not_to receive(:track_exception)

          expect { service.execute }.to change { system_hook.reload.recent_failures }.from(0).to(1)
        end
      end

      context 'when the hook is in the default organization' do
        # rubocop:disable Gitlab/RSpec/AvoidCreateDefaultOrganization -- default organization hooks belong to instance admins
        let_it_be(:organization) { create(:organization, :default) }
        # rubocop:enable Gitlab/RSpec/AvoidCreateDefaultOrganization
        let_it_be_with_reload(:system_hook) { create(:system_hook, organization: organization) }

        it 'does not back off the hook' do
          expect(system_hook).not_to receive(:backoff!)

          expect { service.execute }.not_to change { system_hook.reload.recent_failures }.from(0)
        end
      end
    end

    context 'when an unexpected error occurs while updating hook status' do
      let(:standard_error) { StandardError.new('Unexpected error') }

      before do
        project_hook.update!(recent_failures: 1)
        allow(project_hook).to receive(:enable!).and_raise(standard_error)
      end

      it 'creates the WebHookLog and tracks the exception without raising an error' do
        expect(Gitlab::ErrorTracking).to receive(:track_exception).with(standard_error, hook_id: project_hook.id)

        expect { service.execute }.to change { ::WebHookLog.count }.by(1)
      end
    end

    context 'with url_variables' do
      before do
        project_hook.update!(
          url: 'http://example1.test/{foo}-{bar}',
          url_variables: { 'foo' => 'supers3cret', 'bar' => 'token' }
        )
      end

      let(:data) { super().merge(response_headers: { 'X-Token-Id' => 'supers3cret-token', 'X-Request' => 'PUBLIC-token' }) }
      let(:expected_headers) { { 'X-Token-Id' => '{foo}-{bar}', 'X-Request' => 'PUBLIC-{bar}' } }

      it 'logs the data and masks response headers' do
        expect { service.execute }.to change { ::WebHookLog.count }.by(1)

        expect(WebHookLog.recent.first.response_headers).to eq(expected_headers)
      end
    end

    context 'with X-Gitlab-Token' do
      let(:request_headers) { { 'X-Gitlab-Token' => 'secret_token' } }

      it 'redacts the token' do
        service.execute

        expect(WebHookLog.recent.first.request_headers).to include('X-Gitlab-Token' => '[REDACTED]')
      end
    end
  end
end
