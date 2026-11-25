# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Graphql::Limit::FieldCallRateLimit, feature_category: :api do
  include GraphqlHelpers

  let(:key) { :graphql_participant_fields }
  let(:user) { build_stubbed(:user) }
  let(:request) { instance_double(ActionDispatch::Request, ip: '127.0.0.1') }
  let(:ctx) { { current_user: user, request: request } }
  let(:query) { GraphQL::Query.new(GitlabSchema, context: ctx) }
  let(:owner) { fresh_object_type }
  let(:field) { build_field('value') }

  def build_field(name, **options)
    extension_options = { key: key, threshold: 2 }.merge(options)

    ::Types::BaseField.new(name: name, type: GraphQL::Types::String, null: true, owner: owner) do
      extension(::Gitlab::Graphql::Limit::FieldCallRateLimit, **extension_options)
    end
  end

  def resolve_value(on_field = field, on_query = query)
    resolve_field(on_field, { value: 'foo', other_value: 'foo' }, object_type: owner, query: on_query)
  end

  def stub_throttled(throttled)
    allow(::Gitlab::ApplicationRateLimiter).to receive(:throttled?).and_return(throttled)
  end

  context 'when the field is resolved up to the threshold' do
    it 'resolves it without checking the rate limit', :aggregate_failures do
      expect(::Gitlab::ApplicationRateLimiter).not_to receive(:throttled?)

      expect(Array.new(2) { resolve_value }).to all(eq('foo'))
    end
  end

  context 'when the field is resolved past the threshold' do
    context 'when the caller is not throttled' do
      before do
        stub_throttled(false)
      end

      it 'resolves it and counts the request once', :aggregate_failures do
        expect(Array.new(4) { resolve_value }).to all(eq('foo'))
        expect(::Gitlab::ApplicationRateLimiter).to have_received(:throttled?).with(key, scope: { user: user }).once
      end
    end

    context 'when the caller is throttled' do
      before do
        stub_throttled(true)
      end

      it 'resolves the calls up to the threshold and raises a rate limit error after them', :aggregate_failures do
        expect(Array.new(2) { resolve_value }).to all(eq('foo'))
        expect { resolve_value }.to raise_error(::RateLimitedService::RateLimitedError)
      end
    end
  end

  context 'with fields that share a key' do
    let(:other_field) { build_field('other_value') }

    before do
      stub_throttled(true)
    end

    it 'counts their calls together' do
      resolve_value
      resolve_value(other_field)

      expect { resolve_value(other_field) }.to raise_error(::RateLimitedService::RateLimitedError)
    end
  end

  context 'with fields that use different keys' do
    let(:other_field) { build_field('other_value', key: :other_key) }

    before do
      stub_throttled(true)
    end

    it 'counts their calls separately' do
      2.times { resolve_value }

      expect(resolve_value(other_field)).to eq('foo')
    end
  end

  context 'with queries that share the request context' do
    let(:other_query) { GraphQL::Query.new(GitlabSchema, context: ctx) }

    before do
      stub_throttled(true)
    end

    it 'counts their calls together, as multiplexed queries do' do
      2.times { resolve_value }

      expect { resolve_value(field, other_query) }.to raise_error(::RateLimitedService::RateLimitedError)
    end
  end

  context 'with an anonymous caller' do
    let(:user) { nil }

    before do
      stub_throttled(false)
    end

    it 'counts the request by IP address' do
      3.times { resolve_value }

      expect(::Gitlab::ApplicationRateLimiter).to have_received(:throttled?).with(key, scope: { ip: '127.0.0.1' })
    end

    context 'without a request' do
      let(:request) { nil }

      it 'resolves the field without checking the rate limit', :aggregate_failures do
        expect(Array.new(3) { resolve_value }).to all(eq('foo'))
        expect(::Gitlab::ApplicationRateLimiter).not_to have_received(:throttled?)
      end
    end
  end

  context 'with the throttle bypass header' do
    before do
      stub_throttled(false)
      allow(::Gitlab::Throttle).to receive(:bypass_header).and_return('HTTP_X_GITLAB_BYPASS_RATE_LIMITS')
    end

    it 'passes the header value to the rate limiter' do
      allow(request).to receive(:get_header).with('HTTP_X_GITLAB_BYPASS_RATE_LIMITS').and_return('1')

      3.times { resolve_value }

      expect(::Gitlab::ApplicationRateLimiter)
        .to have_received(:throttled?).with(key, scope: { user: user }, bypass_header: '1')
    end

    it 'does not pass the option when the request has no header value' do
      allow(request).to receive(:get_header).with('HTTP_X_GITLAB_BYPASS_RATE_LIMITS').and_return(nil)

      3.times { resolve_value }

      expect(::Gitlab::ApplicationRateLimiter).to have_received(:throttled?).with(key, scope: { user: user })
    end
  end

  context 'when resolving a subscription update' do
    before do
      stub_throttled(true)
      allow(query).to receive(:subscription_update?).and_return(true)
    end

    it 'resolves the field without counting the call', :aggregate_failures do
      expect(Array.new(3) { resolve_value }).to all(eq('foo'))
      expect(::Gitlab::ApplicationRateLimiter).not_to have_received(:throttled?)
    end
  end

  context 'when the key is not specified' do
    let(:key) { nil }

    it 'raises an error when the field is defined' do
      expect { field.ensure_loaded }.to raise_error(::ArgumentError, 'Rate limit key must be specified.')
    end
  end

  context 'when the threshold is not specified' do
    it 'raises an error when the field is defined' do
      expect { build_field('value', threshold: nil).ensure_loaded }
        .to raise_error(::ArgumentError, 'Threshold must be specified.')
    end
  end
end
