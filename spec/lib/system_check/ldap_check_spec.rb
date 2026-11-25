# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SystemCheck::LdapCheck, feature_category: :system_access do
  include LdapHelpers
  include SystemCheck::Helpers

  subject(:check) { described_class.new }

  before do
    allow(Gitlab::Auth::Ldap::Config).to receive_messages(enabled?: true, providers: %w[ldapmain ldapsecond])
    allow(Gitlab::Auth::Ldap::Adapter).to receive(:config)
      .and_return(instance_double(Gitlab::Auth::Ldap::Config, adapter_options: {}))
  end

  describe '#multi_check' do
    context 'when LDAP is disabled' do
      before do
        allow(Gitlab::Auth::Ldap::Config).to receive(:enabled?).and_return(false)
      end

      it 'says so and checks no server' do
        expect(Gitlab::Auth::Ldap::Adapter).not_to receive(:open)

        expect { check.multi_check }.to output(%r{LDAP is disabled in config/gitlab.yml}).to_stdout
      end
    end

    context 'when a server cannot be reached', :clean_gitlab_redis_shared_state do
      before do
        allow(Gitlab::ErrorTracking).to receive(:track_exception)
        raise_ldap_open_error
      end

      it 'reports the failure rather than raising' do
        expect { check.multi_check }.to output(/Could not connect to the LDAP server/).to_stdout
      end

      it 'carries on to the remaining servers' do
        expect { check.multi_check }.to output(/Server: ldapmain.*Server: ldapsecond/m).to_stdout
      end
    end
  end
end
