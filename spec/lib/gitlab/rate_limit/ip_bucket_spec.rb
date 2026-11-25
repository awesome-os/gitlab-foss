# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::RateLimit::IpBucket, feature_category: :rate_limiting do
  using RSpec::Parameterized::TableSyntax

  describe '.mask' do
    where(:ip, :expected) do
      '1.2.3.4'                              | '1.2.3.4'
      '::ffff:1.2.3.4'                       | '1.2.3.4'
      '2001:db8:1:2:3:4:5:6'                 | '2001:db8:1:2::'
      '2001:db8:1:2:ffff:ffff:ffff:ffff'     | '2001:db8:1:2::'
      '2001:db8:1:3::1'                      | '2001:db8:1:3::'
      '::1'                                  | '::'
      '1.2.3.0/24'                           | '1.2.3.0/24'
      '2001:db8::1/32'                       | '2001:db8::1/32'
      'fe80::1%eth0'                         | 'fe80::1%eth0'
      'not-an-ip'                            | 'not-an-ip'
      '10::20::30::40'                       | '10::20::30::40'
      ''                                     | nil
      nil                                    | nil
    end

    with_them do
      it { expect(described_class.mask(ip, 64)).to eq(expected) }
    end

    it 'returns an address with invalid UTF-8 unchanged' do
      ip = (+"2001:db8::\xff").force_encoding(Encoding::UTF_8)

      expect(described_class.mask(ip, 64)).to eq(ip)
    end

    it 'does not parse an address without a colon' do
      expect(IPAddr).not_to receive(:new)

      expect(described_class.mask('1.2.3.4', 64)).to eq('1.2.3.4')
    end

    it 'masks IPv6 to the given prefix length', :aggregate_failures do
      expect(described_class.mask('2001:db8:1:2:3:4:5:6', 48)).to eq('2001:db8:1::')
      expect(described_class.mask('2001:db8:1:2:3:4:5:6', 128)).to eq('2001:db8:1:2:3:4:5:6')
    end

    it 'does not mask IPv4 with the IPv6 prefix length' do
      expect(described_class.mask('1.2.3.4', 48)).to eq('1.2.3.4')
    end

    context 'when the prefix length is outside 0..128' do
      where(:ipv6_prefix_length) do
        [-1, 129]
      end

      with_them do
        it 'returns the address unchanged' do
          expect(described_class.mask('2001:db8::1', ipv6_prefix_length)).to eq('2001:db8::1')
        end
      end
    end
  end

  describe '.for' do
    it 'buckets IPv6 by the default /64 and keeps IPv4 exact', :aggregate_failures do
      expect(described_class.for('2001:db8:1:2:3:4:5:6')).to eq('2001:db8:1:2::')
      expect(described_class.for('1.2.3.4')).to eq('1.2.3.4')
    end

    it 'buckets IPv6 by the configured prefix length' do
      stub_application_setting(ipv6_rate_limit_prefix_length: 48)

      expect(described_class.for('2001:db8:1:2:3:4:5:6')).to eq('2001:db8:1::')
    end

    it 'returns nil for an empty address' do
      expect(described_class.for('')).to be_nil
    end

    it 'does not read the flag for an IPv4 address' do
      expect(Feature).not_to receive(:enabled?).with(:rate_limiter_bucket_ipv6_by_prefix, anything)

      expect(described_class.for('1.2.3.4')).to eq('1.2.3.4')
    end

    it 'buckets IPv6 by the default /64 with fake application settings' do
      allow(Gitlab::CurrentSettings).to receive(:current_application_settings)
        .and_return(Gitlab::FakeApplicationSettings.new(ApplicationSetting.defaults))

      expect(described_class.for('2001:db8:1:2:3:4:5:6')).to eq('2001:db8:1:2::')
    end

    context 'when rate_limiter_bucket_ipv6_by_prefix is disabled' do
      before do
        stub_feature_flags(rate_limiter_bucket_ipv6_by_prefix: false)
      end

      it 'returns the exact address' do
        expect(described_class.for('2001:db8:1:2:3:4:5:6')).to eq('2001:db8:1:2:3:4:5:6')
      end
    end
  end
end
