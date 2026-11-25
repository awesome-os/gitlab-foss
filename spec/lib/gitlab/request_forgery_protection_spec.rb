# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::RequestForgeryProtection, :allow_forgery_protection do
  let(:csrf_token) { 'YAYvO6dOQJGvIp/7DnZSa42h8AjB5mp0cXGIBgciby8=' }

  let(:env) do
    {
      'rack.input' => StringIO.new(''),
      'rack.session' => {
        _csrf_token: csrf_token
      }
    }
  end

  before do
    allow(env['rack.session']).to receive_messages(enabled?: true, loaded?: true)
  end

  it 'logs to /dev/null' do
    expect(ActiveSupport::Logger).to receive(:new).with(File::NULL)

    described_class::Controller.new.logger
  end

  describe '.call' do
    # These two run the real Rails check, so they fail if an upgrade stops exempting either method.
    %w[GET HEAD].each do |request_method|
      context "when the request method is #{request_method}" do
        before do
          env['REQUEST_METHOD'] = request_method
        end

        it 'does not raise an exception' do
          expect { described_class.call(env) }.not_to raise_exception
        end
      end
    end

    context 'when the request method is POST' do
      before do
        env['REQUEST_METHOD'] = 'POST'
      end

      context 'when the CSRF token is valid' do
        before do
          env['HTTP_X_CSRF_TOKEN'] = csrf_token
        end

        it 'does not raise an exception' do
          expect { described_class.call(env) }.not_to raise_exception
        end
      end

      context 'when the CSRF token is invalid' do
        before do
          env['HTTP_X_CSRF_TOKEN'] = 'foo'
        end

        it 'raises an ActionController::InvalidAuthenticityToken exception' do
          expect { described_class.call(env) }.to raise_exception(ActionController::InvalidAuthenticityToken)
        end
      end
    end
  end

  describe '.verified?' do
    it 'does not modify the env' do
      env['REQUEST_METHOD'] = "GET"
      expect { described_class.verified?(env) }.not_to change { env }
    end

    %w[GET HEAD].each do |request_method|
      context "when the request method is #{request_method}" do
        before do
          env['REQUEST_METHOD'] = request_method
        end

        it 'returns true' do
          expect(described_class.verified?(env)).to be_truthy
        end

        it 'returns true without dispatching the controller' do
          expect(described_class).not_to receive(:call)

          expect(described_class.verified?(env)).to be_truthy
        end

        context 'when the CSRF token is invalid' do
          before do
            env['HTTP_X_CSRF_TOKEN'] = 'foo'
          end

          it 'still returns true' do
            expect(described_class.verified?(env)).to be_truthy
          end
        end

        context 'when the skip_csrf_dispatch_for_safe_methods feature flag is disabled' do
          before do
            stub_feature_flags(skip_csrf_dispatch_for_safe_methods: false)
          end

          it 'returns true by dispatching the controller' do
            expect(described_class).to receive(:call).and_call_original

            expect(described_class.verified?(env)).to be_truthy
          end

          context 'when the CSRF token is invalid' do
            before do
              env['HTTP_X_CSRF_TOKEN'] = 'foo'
            end

            it 'still returns true' do
              expect(described_class.verified?(env)).to be_truthy
            end
          end
        end
      end
    end

    context 'when .verified? is called more than once for the same request', :request_store do
      before do
        env['REQUEST_METHOD'] = 'GET'
      end

      it 'evaluates the feature flag once' do
        allow(Feature).to receive(:enabled?).and_call_original
        expect(Feature).to receive(:enabled?)
          .with(:skip_csrf_dispatch_for_safe_methods, anything).once.and_call_original

        2.times { expect(described_class.verified?(env)).to be_truthy }
      end
    end

    context 'when the request method is POST' do
      before do
        env['REQUEST_METHOD'] = 'POST'
      end

      it 'does not evaluate the feature flag' do
        allow(Feature).to receive(:enabled?).and_call_original
        expect(Feature).not_to receive(:enabled?).with(:skip_csrf_dispatch_for_safe_methods, anything)

        described_class.verified?(env)
      end

      context 'when the CSRF token is valid' do
        before do
          env['HTTP_X_CSRF_TOKEN'] = csrf_token
        end

        it 'returns true' do
          expect(described_class.verified?(env)).to be_truthy
        end
      end

      context 'when the CSRF token is valid and in the body' do
        before do
          env['rack.input'] = StringIO.new("authenticity_token=#{csrf_token}")
        end

        it 'returns true' do
          expect(described_class.verified?(env)).to be_truthy
        end
      end

      context 'when the CSRF token is invalid' do
        before do
          env['HTTP_X_CSRF_TOKEN'] = 'foo'
        end

        it 'returns false' do
          expect(described_class.verified?(env)).to be_falsey
        end
      end

      context 'when there is no CSRF token' do
        it 'returns false' do
          expect(described_class.verified?(env)).to be_falsey
        end
      end
    end
  end
end
