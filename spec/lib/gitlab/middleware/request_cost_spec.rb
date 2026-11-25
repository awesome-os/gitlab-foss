# frozen_string_literal: true

require 'spec_helper'
require 'rack'

RSpec.describe Gitlab::Middleware::RequestCost, :request_store, feature_category: :rate_limiting do
  let(:app) { instance_double(Rack::Builder) }
  let(:middleware) { described_class.new(app) }
  let(:env) { {} }
  let(:status) { 200 }
  let(:headers) { {} }
  let(:body) { ['OK'] }
  let(:root_namespace) { 'my-group' }

  before do
    allow(app).to receive(:call).with(env).and_return([status, headers, body])
    allow(Gitlab::ApplicationContext).to receive(:current_context_attribute)
      .with(:root_namespace).and_return(root_namespace)
  end

  describe '#call' do
    subject(:result_headers) { middleware.call(env)[1] }

    context 'when both feature flags are disabled' do
      before do
        stub_feature_flags(root_namespace_response_header: false, request_cost_headers: false)
        Gitlab::RequestCost.current.add(5, resource: :gitaly)
      end

      it 'does not read cost or emit headers' do
        expect(Gitlab::RequestCost).not_to receive(:current)

        expect(result_headers).not_to have_key('x-gitlab-score-gitaly')
        expect(result_headers).not_to have_key('x-gitlab-namespace')
      end
    end

    context 'when only root_namespace_response_header is enabled' do
      before do
        stub_feature_flags(request_cost_headers: false)
      end

      it 'sets the namespace header without a Gitaly cost' do
        expect(result_headers['x-gitlab-namespace']).to eq('my-group')
        expect(result_headers).not_to have_key('x-gitlab-score-gitaly')
      end

      context 'with Gitaly cost' do
        before do
          Gitlab::RequestCost.current.add(3, resource: :gitaly)
        end

        it 'sets the namespace header only' do
          expect(result_headers['x-gitlab-namespace']).to eq('my-group')
          expect(result_headers).not_to have_key('x-gitlab-score-gitaly')
        end
      end

      context 'without a namespace' do
        let(:root_namespace) { nil }

        it 'omits both headers' do
          expect(result_headers).not_to have_key('x-gitlab-score-gitaly')
          expect(result_headers).not_to have_key('x-gitlab-namespace')
        end
      end
    end

    context 'when only request_cost_headers is enabled' do
      before do
        stub_feature_flags(root_namespace_response_header: false)
      end

      context 'with Gitaly cost' do
        before do
          Gitlab::RequestCost.current.add(3, resource: :gitaly)
        end

        it 'sets the score header only' do
          expect(result_headers['x-gitlab-score-gitaly']).to eq('3')
          expect(result_headers).not_to have_key('x-gitlab-namespace')
        end
      end

      context 'when no Gitaly cost is present' do
        it 'omits both headers' do
          expect(result_headers).not_to have_key('x-gitlab-score-gitaly')
          expect(result_headers).not_to have_key('x-gitlab-namespace')
        end
      end

      context 'without a namespace' do
        let(:root_namespace) { nil }

        before do
          Gitlab::RequestCost.current.add(2, resource: :gitaly)
        end

        it 'omits both headers' do
          # The score is only actionable when paired with a namespace bucket
          # for Cloudflare; emitting it alone would skew the no-bucket pool.
          expect(result_headers).not_to have_key('x-gitlab-score-gitaly')
          expect(result_headers).not_to have_key('x-gitlab-namespace')
        end
      end
    end

    context 'when both feature flags are enabled' do
      context 'with Gitaly cost' do
        before do
          Gitlab::RequestCost.current.add(3, resource: :gitaly)
        end

        it 'sets gitaly score and namespace headers' do
          expect(result_headers['x-gitlab-score-gitaly']).to eq('3')
          expect(result_headers['x-gitlab-namespace']).to eq('my-group')
        end
      end

      context 'when no Gitaly cost is present' do
        it 'sets the namespace header only' do
          expect(result_headers['x-gitlab-namespace']).to eq('my-group')
          expect(result_headers).not_to have_key('x-gitlab-score-gitaly')
        end
      end

      context 'without a namespace' do
        let(:root_namespace) { nil }

        before do
          Gitlab::RequestCost.current.add(2, resource: :gitaly)
        end

        it 'omits both headers' do
          expect(result_headers).not_to have_key('x-gitlab-score-gitaly')
          expect(result_headers).not_to have_key('x-gitlab-namespace')
        end
      end

      context 'when response already has headers' do
        let(:headers) { { 'X-Custom' => 'value' } }

        before do
          Gitlab::RequestCost.current.add(1, resource: :gitaly)
        end

        it 'preserves existing headers' do
          expect(result_headers['X-Custom']).to eq('value')
          expect(result_headers['x-gitlab-score-gitaly']).to eq('1')
          expect(result_headers['x-gitlab-namespace']).to eq('my-group')
        end
      end
    end
  end
end
