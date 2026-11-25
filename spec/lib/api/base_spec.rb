# frozen_string_literal: true

require 'spec_helper'

# rubocop:disable Rails/HttpPositionalArguments
RSpec.describe ::API::Base do
  let(:app_hello) do
    route = double(:route, request_method: 'GET', path: '/:version/test/hello')
    double(:endpoint, route: route, options: { for: api_handler, path: ["hello"] }, namespace: '/test')
  end

  let(:app_hi) do
    route = double(:route, request_method: 'GET', path: '/:version//test/hi')
    double(:endpoint, route: route, options: { for: api_handler, path: ["hi"] }, namespace: '/test')
  end

  describe '.endpoint_id_for_route' do
    it 'combines the request method and origin for a declared route' do
      route = API::API.routes.find { |r| r.request_method == 'GET' }

      expect(described_class.endpoint_id_for_route(route)).to match(%r{\AGET /api/:version/})
    end

    it 'returns nil for the routes Grape generates for OPTIONS and 405 responses' do
      # allocate: GreedyRoute's constructor differs between Grape 2.4 and 3.x, and the
      # guard returns before reading any of the route's state.
      greedy_route = Grape::Router::GreedyRoute.allocate

      expect(described_class.endpoint_id_for_route(greedy_route)).to be_nil
    end
  end

  describe 'declare feature categories at handler level for all routes' do
    let(:api_handler) do
      Class.new(described_class) do
        feature_category :foo
        urgency :medium

        namespace '/test' do
          get 'hello' do
            nil
          end
          post 'hi' do
            nil
          end
        end
      end
    end

    it 'sets feature category for a particular route', :aggregate_failures do
      expect(api_handler.feature_category_for_app(app_hello)).to eq(:foo)
      expect(api_handler.feature_category_for_app(app_hi)).to eq(:foo)
    end

    it 'sets request urgency for a particular route', :aggregate_failures do
      expect(api_handler.urgency_for_app(app_hello)).to be_request_urgency(:medium)
      expect(api_handler.urgency_for_app(app_hi)).to be_request_urgency(:medium)
    end
  end

  describe 'declare feature categories at route level' do
    let(:api_handler) do
      Class.new(described_class) do
        namespace '/test' do
          get 'hello', feature_category: :foo, urgency: :low do
            nil
          end
          post 'hi', feature_category: :bar, urgency: :medium do
            nil
          end
        end
      end
    end

    it 'sets feature category for a particular route', :aggregate_failures do
      expect(api_handler.feature_category_for_app(app_hello)).to eq(:foo)
      expect(api_handler.feature_category_for_app(app_hi)).to eq(:bar)
    end

    it 'sets request urgency for a particular route', :aggregate_failures do
      expect(api_handler.urgency_for_app(app_hello)).to be_request_urgency(:low)
      expect(api_handler.urgency_for_app(app_hi)).to be_request_urgency(:medium)
    end
  end

  describe 'declare feature categories at both handler level and route level' do
    let(:api_handler) do
      Class.new(described_class) do
        feature_category :foo, ['/test/hello']
        urgency :low, ['/test/hello']

        namespace '/test' do
          get 'hello' do
            nil
          end
          post 'hi', feature_category: :bar, urgency: :medium do
            nil
          end
        end
      end
    end

    it 'sets feature category for a particular route', :aggregate_failures do
      expect(api_handler.feature_category_for_app(app_hello)).to eq(:foo)
      expect(api_handler.feature_category_for_app(app_hi)).to eq(:bar)
    end

    it 'sets target duration for a particular route', :aggregate_failures do
      expect(api_handler.urgency_for_app(app_hello)).to be_request_urgency(:low)
      expect(api_handler.urgency_for_app(app_hi)).to be_request_urgency(:medium)
    end
  end

  describe 'declare feature categories at route level in a class mounted under a prefix' do
    def mount_under_prefix(handler)
      Class.new(described_class) do
        namespace('/prefix') { mount handler }
      end
    end

    def app_for(handler, path)
      handler.endpoints.find { |endpoint| endpoint.options[:path] == [path] }
    end

    it 'sets feature category and urgency for a particular route', :aggregate_failures do
      handler = Class.new(described_class) do
        get('hello', feature_category: :foo, urgency: :low) { nil }
      end
      mount_under_prefix(handler)

      expect(handler.feature_category_for_app(app_for(handler, 'hello'))).to eq(:foo)
      expect(handler.urgency_for_app(app_for(handler, 'hello'))).to be_request_urgency(:low)
    end

    it 'lets a route override the class-level urgency', :aggregate_failures do
      handler = Class.new(described_class) do
        urgency :low

        get('hello') { nil }
        get('hi', urgency: :default) { nil }
      end
      mount_under_prefix(handler)

      expect(handler.urgency_for_app(app_for(handler, 'hello'))).to be_request_urgency(:low)
      expect(handler.urgency_for_app(app_for(handler, 'hi'))).to be_request_urgency(:default)
    end

    context 'when the class is mounted inside another mounted class' do
      let(:handler) do
        Class.new(described_class) do
          get('hello', urgency: :low) { nil }
        end
      end

      let(:middle) do
        inner = handler
        Class.new(described_class) do
          namespace('/middle') { mount inner }
        end
      end

      it 'applies the outer prefix too' do
        mount_under_prefix(middle)

        expect(handler.urgency_for_app(app_for(handler, 'hello'))).to be_request_urgency(:low)
      end

      it 'applies the outer prefix when mounted with a path' do
        inner = middle
        Class.new(described_class) do
          namespace('/prefix') { mount inner => '/' }
        end

        expect(handler.urgency_for_app(app_for(handler, 'hello'))).to be_request_urgency(:low)
      end
    end

    it 'raises when a route sets an unknown urgency' do
      expect { Class.new(described_class) { get('hello', urgency: :whenever) { nil } } }
        .to raise_error(ArgumentError, 'Urgency not supported: whenever')
    end

    it 'raises on mount when routes on the same path set different urgencies' do
      handler = Class.new(described_class) do
        get('hello', urgency: :low) { nil }
        delete('hello', urgency: :high) { nil }
      end

      expect { Class.new(described_class) { mount handler } }
        .to raise_error(ArgumentError, /Attributes re-defined for action/)
    end
  end
end
# rubocop:enable Rails/HttpPositionalArguments
