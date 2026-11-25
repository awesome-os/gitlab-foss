# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Auth::Ldap::Adapter, feature_category: :system_access do
  include LdapHelpers

  let(:ldap) { double(:ldap) }
  let(:adapter) { ldap_adapter('ldapmain', ldap) }

  describe '.open', :clean_gitlab_redis_shared_state, feature_category: :system_access do
    let(:provider) { 'ldapmain' }
    let(:config) { instance_double(Gitlab::Auth::Ldap::Config, adapter_options: {}) }

    before do
      allow(described_class).to receive(:config).with(provider).and_return(config)
      allow(Gitlab::ErrorTracking).to receive(:track_exception)
      allow(Gitlab::ErrorTracking).to receive(:log_exception)
    end

    context 'when the connection succeeds' do
      before do
        allow(Net::LDAP).to receive(:open).and_yield(ldap)
      end

      it 'yields an adapter without consuming the reporting budget', :aggregate_failures do
        expect(Gitlab::Utils::RedisThrottle).not_to receive(:execute_every)

        expect { |block| described_class.open(provider, &block) }.to yield_with_args(described_class)
        expect(Gitlab::ErrorTracking).not_to have_received(:track_exception)
        expect(Gitlab::ErrorTracking).not_to have_received(:log_exception)
      end

      [Errno::ECONNREFUSED, Net::LDAP::Error].each do |error_class|
        it "lets #{error_class} raised inside the block through unchanged", :aggregate_failures do
          error = error_class.new('block failure')
          expect(Gitlab::Utils::RedisThrottle).not_to receive(:execute_every)

          expect { described_class.open(provider) { raise error } }
            .to raise_error { |raised| expect(raised).to be(error) }
          expect(Gitlab::ErrorTracking).not_to have_received(:track_exception)
          expect(Gitlab::ErrorTracking).not_to have_received(:log_exception)
        end
      end
    end

    context 'when the connection is refused' do
      before do
        raise_ldap_open_error
      end

      it 'raises ConnectionFailedError' do
        expect { described_class.open(provider) { |adapter| adapter } }.to raise_error(
          Gitlab::Auth::Ldap::ConnectionFailedError,
          "LDAP connection to #{provider} raised exception Errno::ECONNREFUSED: Connection refused"
        )
      end

      it 'is rescuable as LdapConnectionError' do
        expect { described_class.open(provider) { |adapter| adapter } }
          .to raise_error(Gitlab::Auth::Ldap::LdapConnectionError)
      end

      it 'does not yield the adapter', :aggregate_failures do
        yielded = false

        expect { described_class.open(provider) { yielded = true } }
          .to raise_error(Gitlab::Auth::Ldap::ConnectionFailedError)
        expect(yielded).to be(false)
      end

      it 'tracks the error', :aggregate_failures do
        expect { described_class.open(provider) { |adapter| adapter } }
          .to raise_error(Gitlab::Auth::Ldap::ConnectionFailedError)
        expect(Gitlab::ErrorTracking).to have_received(:track_exception)
          .with(instance_of(Errno::ECONNREFUSED), provider: provider)
      end
    end

    context 'when reporting connection failures' do
      let(:redis_key) { "ldap:connection_error:#{provider}" }
      let(:error) { Errno::ECONNREFUSED.new }

      before do
        allow(Net::LDAP).to receive(:open).and_raise(error)
      end

      def connection_failure(provider)
        described_class.open(provider) { |adapter| adapter }
      rescue Gitlab::Auth::Ldap::ConnectionFailedError => error
        error
      end

      it 'tracks the first failure and logs every later failure once', :aggregate_failures do
        errors = [error, Net::LDAP::Error.new('another connection failure'), Errno::ECONNREFUSED.new]
        allow(Net::LDAP).to receive(:open) { raise errors.shift }

        failures = Array.new(3) { connection_failure(provider) }

        expect(failures).to all(be_a(Gitlab::Auth::Ldap::ConnectionFailedError))
        expect(failures.first.cause).to be(error)
        expect(Net::LDAP).to have_received(:open).exactly(3).times
        expect(Gitlab::ErrorTracking).to have_received(:track_exception).with(error, provider: provider).once
        expect(Gitlab::ErrorTracking).to have_received(:log_exception)
          .with(instance_of(Net::LDAP::Error), provider: provider).once
        expect(Gitlab::ErrorTracking).to have_received(:log_exception)
          .with(instance_of(Errno::ECONNREFUSED), provider: provider).once
      end

      it 'keeps the exact provider identifiers independent', :aggregate_failures do
        other_provider = 'LDAPmain'
        allow(described_class).to receive(:config).with(other_provider).and_return(config)

        failures = [provider, other_provider, provider, other_provider].map { |name| connection_failure(name) }

        expect(failures).to all(be_a(Gitlab::Auth::Ldap::ConnectionFailedError))
        expect(Net::LDAP).to have_received(:open).exactly(4).times
        [provider, other_provider].each do |name|
          expect(Gitlab::ErrorTracking).to have_received(:track_exception).with(error, provider: name).once
          expect(Gitlab::ErrorTracking).to have_received(:log_exception).with(error, provider: name).once
        end
      end

      it 'uses a fixed ten-minute cooldown without refreshing suppressed failures', :aggregate_failures do
        connection_failure(provider)

        Gitlab::Redis::SharedState.with do |redis|
          expect(redis.get(redis_key)).to eq('1')
          expect(redis.ttl(redis_key)).to be_between(590, 600)
          redis.expire(redis_key, 30)
        end

        expect(connection_failure(provider)).to be_a(Gitlab::Auth::Ldap::ConnectionFailedError)

        Gitlab::Redis::SharedState.with do |redis|
          expect(redis.ttl(redis_key)).to be_between(1, 30)
          redis.expire(redis_key, 0)
          expect(redis.exists?(redis_key)).to be(false)
        end

        expect(connection_failure(provider)).to be_a(Gitlab::Auth::Ldap::ConnectionFailedError)
        expect(Net::LDAP).to have_received(:open).exactly(3).times
        expect(Gitlab::ErrorTracking).to have_received(:track_exception).with(error, provider: provider).twice
        expect(Gitlab::ErrorTracking).to have_received(:log_exception).with(error, provider: provider).once
        expect(Gitlab::Redis::SharedState.with { |redis| redis.ttl(redis_key) }).to be_between(590, 600)
      end

      it 'does not reset the cooldown after a successful connection', :aggregate_failures do
        connection_failure(provider)
        allow(Net::LDAP).to receive(:open).and_yield(ldap)

        expect { |block| described_class.open(provider, &block) }.to yield_with_args(described_class)

        allow(Net::LDAP).to receive(:open).and_raise(error)

        expect(connection_failure(provider)).to be_a(Gitlab::Auth::Ldap::ConnectionFailedError)
        expect(Net::LDAP).to have_received(:open).exactly(3).times
        expect(Gitlab::ErrorTracking).to have_received(:track_exception).with(error, provider: provider).once
        expect(Gitlab::ErrorTracking).to have_received(:log_exception).with(error, provider: provider).once
      end

      it 'also throttles in development', :aggregate_failures do
        allow(Rails.env).to receive(:development?).and_return(true)

        2.times { connection_failure(provider) }

        expect(Gitlab::ErrorTracking).to have_received(:track_exception).with(error, provider: provider).once
        expect(Gitlab::ErrorTracking).to have_received(:log_exception).with(error, provider: provider).once
      end

      it 'admits one concurrent Sentry report while logging every failed attempt', :aggregate_failures do
        ready = Queue.new
        start = Queue.new
        reports = Queue.new
        allow(Gitlab::ErrorTracking).to receive(:track_exception) { reports << :track }
        allow(Gitlab::ErrorTracking).to receive(:log_exception) { reports << :log }
        allow(Gitlab::Utils::RedisThrottle).to receive(:execute_every).and_call_original

        threads = Array.new(6) do
          Thread.new do
            ready << true
            start.pop
            connection_failure(provider)
          end
        end

        Timeout.timeout(10) { threads.size.times { ready.pop } }
        threads.size.times { start << true }
        failures = Timeout.timeout(10) { threads.map(&:value) }
        reporting = Array.new(reports.size) { reports.pop }

        expect(failures).to all(be_a(Gitlab::Auth::Ldap::ConnectionFailedError))
        expect(failures.map(&:cause)).to all(be(error))
        expect(Net::LDAP).to have_received(:open).exactly(6).times
        expect(reporting.count(:track)).to eq(1)
        expect(reporting.count(:log)).to eq(5)
      ensure
        threads&.each do |thread|
          thread.kill if thread.alive?
          thread.join
        end
      end

      [Redis::BaseError, RedisClient::Error, ConnectionPool::TimeoutError].each do |error_class|
        context "when admission raises #{error_class}" do
          before do
            allow(Gitlab::Redis::SharedState).to receive(:with).and_raise(error_class, 'unavailable')
          end

          it 'preserves the original report and connection failure', :aggregate_failures do
            failures = Array.new(2) { connection_failure(provider) }

            expect(failures).to all(be_a(Gitlab::Auth::Ldap::ConnectionFailedError))
            expect(failures.map(&:cause)).to all(be(error))
            expect(Net::LDAP).to have_received(:open).twice
            expect(Gitlab::ErrorTracking).to have_received(:track_exception).with(error, provider: provider).twice
            expect(Gitlab::ErrorTracking).not_to have_received(:log_exception)
          end
        end
      end

      [:track_exception, :log_exception].each do |reporter|
        it "does not catch or retry #{reporter} errors", :aggregate_failures do
          Gitlab::Redis::SharedState.with { |redis| redis.set(redis_key, 1, ex: 600) } if reporter == :log_exception
          reporter_error = Redis::BaseError.new('reporter failure')
          allow(Gitlab::ErrorTracking).to receive(reporter).and_raise(reporter_error)

          expect { described_class.open(provider) { |adapter| adapter } }
            .to raise_error { |raised| expect(raised).to be(reporter_error) }
          expect(Gitlab::ErrorTracking).to have_received(reporter).once
          expect(Gitlab::Redis::SharedState.with { |redis| redis.exists?(redis_key) }).to be(true)
        end
      end

      it 'routes one event to Sentry and every event to the local exception logger', :aggregate_failures do
        allow(Gitlab::ErrorTracking).to receive(:track_exception).and_call_original
        allow(Gitlab::ErrorTracking).to receive(:log_exception).and_call_original
        allow(Gitlab::ErrorTracking).to receive(:default_trackers).and_return([Sentry, Gitlab::ErrorTracking::Logger])
        allow(Sentry).to receive(:capture_exception)
        allow(Gitlab::ErrorTracking::Logger).to receive(:capture_exception).and_call_original
        allow(Gitlab::ErrorTracking::Logger).to receive(:error).and_call_original

        3.times { connection_failure(provider) }

        expect(Sentry).to have_received(:capture_exception).with(error, any_args).once
        expect(Gitlab::ErrorTracking::Logger).to have_received(:capture_exception)
          .with(error, any_args).exactly(3).times
        expect(Gitlab::ErrorTracking::Logger).to have_received(:error)
          .with(hash_including('extra.provider' => provider, 'exception.class' => 'Errno::ECONNREFUSED')).exactly(3).times
      end
    end

    context 'when the hostname cannot be resolved' do
      before do
        raise_ldap_open_error(Net::LDAP::Error.new('getaddrinfo: Name or service not known'))
      end

      it 'raises ConnectionFailedError' do
        expect { described_class.open(provider) { |adapter| adapter } }.to raise_error(
          Gitlab::Auth::Ldap::ConnectionFailedError,
          "LDAP connection to #{provider} raised exception " \
            "Net::LDAP::Error: getaddrinfo: Name or service not known"
        )
      end
    end
  end

  describe '#users' do
    before do
      stub_ldap_config(base: 'dc=example,dc=com')
    end

    it 'searches with the proper options when searching by uid' do
      # Requires this expectation style to match the filter
      expect(adapter).to receive(:ldap_search) do |arg|
        expect(arg[:filter].to_s).to eq('(uid=johndoe)')
        expect(arg[:base]).to eq('dc=example,dc=com')
        expect(arg[:attributes]).to match(ldap_attributes)
      end.and_return({})

      adapter.users('uid', 'johndoe')
    end

    it 'searches with the proper options when searching by dn' do
      expect(adapter).to receive(:ldap_search).with(
        {
          base: 'uid=johndoe,ou=users,dc=example,dc=com',
          scope: Net::LDAP::SearchScope_BaseObject,
          attributes: ldap_attributes,
          filter: nil
        }
      ).and_return({})

      adapter.users('dn', 'uid=johndoe,ou=users,dc=example,dc=com')
    end

    it 'searches with the proper options when searching with a limit' do
      expect(adapter)
        .to receive(:ldap_search).with(hash_including(size: 100)).and_return({})

      adapter.users('uid', 'johndoe', 100)
    end

    it 'returns an LDAP::Person if search returns a result' do
      entry = ldap_user_entry('johndoe')
      allow(adapter).to receive(:ldap_search).and_return([entry])

      results = adapter.users('uid', 'johndoe')

      expect(results.size).to eq(1)
      expect(results.first.uid).to eq('johndoe')
    end

    it 'returns empty array if search entry does not respond to uid' do
      entry = Net::LDAP::Entry.new
      entry['dn'] = user_dn('johndoe')
      allow(adapter).to receive(:ldap_search).and_return([entry])

      results = adapter.users('uid', 'johndoe')

      expect(results).to be_empty
    end

    it 'uses the right uid attribute when non-default' do
      stub_ldap_config(uid: 'sAMAccountName')
      expect(adapter).to receive(:ldap_search).with(
        hash_including(attributes: ldap_attributes)
      ).and_return({})

      adapter.users('sAMAccountName', 'johndoe')
    end
  end

  describe '#dn_matches_filter?' do
    subject { adapter.dn_matches_filter?(:dn, :filter) }

    context "when the search result is non-empty" do
      before do
        allow(adapter).to receive(:ldap_search).and_return([:foo])
      end

      it { is_expected.to be_truthy }
    end

    context "when the search result is empty" do
      before do
        allow(adapter).to receive(:ldap_search).and_return([])
      end

      it { is_expected.to be_falsey }
    end
  end

  describe '#ldap_search' do
    subject { adapter.ldap_search(base: :dn, filter: :filter) }

    shared_examples 'connection retry' do
      before do
        allow(adapter).to receive(:renew_connection_adapter).and_return(ldap)
        allow(Gitlab::AppLogger).to receive(:warn)
      end

      context 'retries the operation' do
        before do
          stub_const("#{described_class}::MAX_SEARCH_RETRIES", 3)
        end

        it 'as many times as MAX_SEARCH_RETRIES' do
          expect(ldap).to receive(:search).exactly(3).times
          expect { subject }.to raise_error(Gitlab::Auth::Ldap::LdapConnectionError)
        end

        context 'when no more retries' do
          before do
            stub_const("#{described_class}::MAX_SEARCH_RETRIES", 1)
          end

          it 'raises the exception' do
            expect { subject }.to raise_error(Gitlab::Auth::Ldap::LdapConnectionError)
          end

          it 'logs the error' do
            expect { subject }.to raise_error(Gitlab::Auth::Ldap::LdapConnectionError)
            expect(Gitlab::AppLogger).to have_received(:warn).with(
              "LDAP search raised exception Net::LDAP::Error: #{err_message}")
          end
        end
      end
    end

    context "when the search is successful" do
      context "and the result is non-empty" do
        before do
          allow(ldap).to receive(:search).and_return([:foo])
        end

        it { is_expected.to eq [:foo] }
      end

      context "and the result is empty" do
        before do
          allow(ldap).to receive(:search).and_return([])
        end

        it { is_expected.to eq [] }

        context 'when returned with expected code' do
          let(:response_code) { 80 }
          let(:response_message) { 'Other' }
          let(:err_message) { "Got empty results with response code: #{response_code}, message: #{response_message}" }

          before do
            stub_ldap_config(retry_empty_result_with_codes: [response_code])
            allow(ldap).to receive_messages(
              search: nil,
              get_operation_result: double(code: response_code, message: response_message)
            )
          end

          it_behaves_like 'connection retry'
        end
      end
    end

    context "when the search encounters an error" do
      before do
        allow(ldap).to receive_messages(
          search: nil,
          get_operation_result: double(code: 1, message: 'some error')
        )
        allow(Gitlab::AppLogger).to receive(:warn)
      end

      context 'when ldap_raise_on_search_error is enabled' do
        before do
          stub_feature_flags(ldap_raise_on_search_error: true)
        end

        let(:err_message) { "LDAP search error code: 1, message: some error" }

        it_behaves_like 'connection retry'
      end

      context 'when ldap_raise_on_search_error is disabled' do
        before do
          stub_feature_flags(ldap_raise_on_search_error: false)
        end

        it { is_expected.to eq [] }

        it 'logs a warning with the response code' do
          adapter.ldap_search(base: :dn, filter: :filter)
          expect(Gitlab::AppLogger).to have_received(:warn).with(
            "LDAP search error code: 1, message: some error"
          )
        end
      end
    end

    context "when the search returns nil with a success response code" do
      before do
        allow(ldap).to receive_messages(
          search: nil,
          get_operation_result: double(code: 0, message: 'Success')
        )
        allow(Gitlab::AppLogger).to receive(:warn)
      end

      it { is_expected.to eq [] }

      it 'does not log a warning' do
        adapter.ldap_search(base: :dn, filter: :filter)
        expect(Gitlab::AppLogger).not_to have_received(:warn)
      end
    end

    context "when the search returns nil with a non-error response code" do
      using RSpec::Parameterized::TableSyntax

      where(:code, :message) do
        10 | 'Referral'
        32 | 'No Such Object'
      end

      with_them do
        before do
          allow(ldap).to receive_messages(
            search: nil,
            get_operation_result: double(code: code, message: message)
          )
          allow(Gitlab::AppLogger).to receive(:warn)
        end

        it 'returns an empty array' do
          expect(adapter.ldap_search(base: :dn, filter: :filter)).to eq([])
        end

        it 'logs a warning with the response code' do
          adapter.ldap_search(base: :dn, filter: :filter)
          expect(Gitlab::AppLogger).to have_received(:warn).with(
            "LDAP search error code: #{code}, message: #{message}"
          )
        end
      end
    end

    context "when the search raises an LDAP exception" do
      before do
        allow(adapter).to receive(:renew_connection_adapter).and_return(ldap)
        allow(ldap).to receive(:search) { raise Net::LDAP::Error, "some error" }
        allow(Gitlab::AppLogger).to receive(:warn)
      end

      context 'retries the operation' do
        let(:err_message) { 'some error' }

        before do
          allow(ldap).to receive(:search) { raise Net::LDAP::Error, err_message }
        end

        it_behaves_like 'connection retry'
      end
    end

    context 'when the renewed connection is refused' do
      let(:renewed_ldap) { double(:renewed_ldap) }

      before do
        stub_const("#{described_class}::MAX_SEARCH_RETRIES", 2)
        allow(ldap).to receive(:search).and_raise(Net::LDAP::Error, 'Connection reset by peer')
        allow(Net::LDAP).to receive(:new).and_return(renewed_ldap)
        allow(renewed_ldap).to receive(:search).and_raise(Errno::ECONNREFUSED)
        allow(Gitlab::AppLogger).to receive(:warn)
      end

      it 'raises LdapConnectionError after retrying on the renewed connection', :aggregate_failures do
        expect { adapter.ldap_search(base: :dn, filter: :filter) }.to raise_error(
          Gitlab::Auth::Ldap::LdapConnectionError,
          'LDAP search raised exception Errno::ECONNREFUSED: Connection refused'
        )
        expect(ldap).to have_received(:search).once
        expect(renewed_ldap).to have_received(:search).once
      end
    end
  end

  def ldap_attributes
    Gitlab::Auth::Ldap::Person.ldap_attributes(Gitlab::Auth::Ldap::Config.new('ldapmain'))
  end
end
