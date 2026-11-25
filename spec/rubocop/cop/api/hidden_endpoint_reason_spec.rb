# frozen_string_literal: true

require 'rubocop_spec_helper'
require_relative '../../../../rubocop/cop/api/hidden_endpoint_reason'

RSpec.describe RuboCop::Cop::API::HiddenEndpointReason, :config, feature_category: :api do
  let(:msg) do
    'Endpoints marked `hidden true` must record why they are left out of the OpenAPI spec. ' \
      'Add `route_setting :lifecycle` or `route_setting :openapi_hidden_reason` to this endpoint. ' \
      'See https://docs.gitlab.com/development/api_styleguide/#marking-endpoints-as-hidden'
  end

  context 'when a hidden endpoint records no reason' do
    it 'registers an offense on `hidden true` in the desc block' do
      expect_offense(<<~RUBY)
        desc 'Authorize a file upload' do
          detail 'Workhorse calls this before the upload.'
          hidden true
          ^^^^^^^^^^^ #{msg}
        end
        route_setting :authorization, skip_granular_token_authorization: :workhorse_pre_authorization
        post 'authorize' do
        end
      RUBY
    end

    it 'registers an offense on `hidden: true` in the desc options' do
      expect_offense(<<~RUBY)
        desc 'List approval rules', { hidden: true, tags: ['merge_request_approvals'] }
                                      ^^^^^^^^^^^^ #{msg}
        get 'approval_settings' do
        end
      RUBY
    end

    it 'does not count a setting that belongs to the previous endpoint' do
      expect_offense(<<~RUBY)
        namespace 'registries' do
          route_setting :lifecycle, :experiment
          desc 'List registries' do
            hidden true
          end
          get do
          end

          desc 'Create a registry' do
            hidden true
            ^^^^^^^^^^^ #{msg}
          end
          post do
          end
        end
      RUBY
    end

    it 'does not count a setting that belongs to the next endpoint' do
      expect_offense(<<~RUBY)
        desc 'Authorize a file upload' do
          hidden true
          ^^^^^^^^^^^ #{msg}
        end
        post 'authorize' do
        end
        route_setting :openapi_hidden_reason, :internal
        put 'authorize' do
        end
      RUBY
    end

    it 'does not count an enclosing setting that an earlier endpoint in that namespace used' do
      expect_offense(<<~RUBY)
        namespace 'outer' do
          route_setting :lifecycle, :experiment
          get 'first' do
          end

          namespace 'inner' do
            desc 'Get the second item' do
              hidden true
              ^^^^^^^^^^^ #{msg}
            end
          end
        end
      RUBY
    end

    it 'does not count a setting above a namespace whose earlier endpoint used it' do
      expect_offense(<<~RUBY)
        namespace 'top' do
          route_setting :lifecycle, :experiment
          namespace 'middle' do
            get 'first' do
            end

            namespace 'inner' do
              desc 'Get the second item' do
                hidden true
                ^^^^^^^^^^^ #{msg}
              end
            end
          end
        end
      RUBY
    end

    it 'registers an offense when the desc has no sibling statements' do
      expect_offense(<<~RUBY)
        desc 'Authorize a file upload' do
          hidden true
          ^^^^^^^^^^^ #{msg}
        end
      RUBY
    end

    it 'checks identical desc blocks separately' do
      expect_offense(<<~RUBY)
        desc 'Authorize a file upload' do
          hidden true
        end
        route_setting :openapi_hidden_reason, :internal
        post 'authorize' do
        end

        desc 'Authorize a file upload' do
          hidden true
          ^^^^^^^^^^^ #{msg}
        end
        put 'authorize' do
        end
      RUBY
    end
  end

  context 'when a hidden endpoint records a reason' do
    it 'does not register an offense for a lifecycle setting after the desc' do
      expect_no_offenses(<<~RUBY)
        desc 'Create a registry' do
          hidden true
        end
        params do
          requires :name, type: String
        end
        route_setting :lifecycle, :experiment
        post do
        end
      RUBY
    end

    it 'does not register an offense for a hidden reason setting' do
      expect_no_offenses(<<~RUBY)
        desc 'Authorize a file upload' do
          hidden true
        end
        route_setting :openapi_hidden_reason, :internal
        post 'authorize' do
        end
      RUBY
    end

    it 'does not register an offense for a setting before the desc' do
      expect_no_offenses(<<~RUBY)
        namespace 'mcp' do
          route_setting :openapi_hidden_reason, :other_protocol
          desc 'Handle a JSON-RPC request' do
            hidden true
          end
          post do
          end
        end
      RUBY
    end
  end

  context 'when the reason is set in an enclosing namespace' do
    it 'does not register an offense for any endpoint in the nested namespaces' do
      expect_no_offenses(<<~RUBY)
        namespace 'outer' do
          route_setting :lifecycle, :experiment
          namespace 'inner' do
            desc 'Get one' do
              hidden true
            end
            get 'one' do
            end

            desc 'Get two' do
              hidden true
            end
            get 'two' do
            end
          end

          namespace 'other' do
            desc 'Get three' do
              hidden true
            end
          end
        end
      RUBY
    end
  end

  context 'when an endpoint is not hidden' do
    it 'does not register an offense' do
      expect_no_offenses(<<~RUBY)
        desc 'List projects' do
          tags %w[projects]
        end
        get do
        end
      RUBY
    end
  end

  context 'with route_setting :openapi_hidden_reason values' do
    it 'does not register an offense for :internal or :other_protocol' do
      expect_no_offenses(<<~RUBY)
        route_setting :openapi_hidden_reason, :internal
        route_setting :openapi_hidden_reason, :other_protocol
      RUBY
    end

    it 'registers an offense for an unknown reason' do
      expect_offense(<<~RUBY)
        route_setting :openapi_hidden_reason, :unfinished
                                              ^^^^^^^^^^^ Invalid OpenAPI hidden reason `:unfinished`. Use one of: :internal, :other_protocol.
      RUBY
    end

    it 'registers an offense for a string instead of a symbol' do
      expect_offense(<<~RUBY)
        route_setting :openapi_hidden_reason, 'internal'
                                              ^^^^^^^^^^ Invalid OpenAPI hidden reason `'internal'`. Use one of: :internal, :other_protocol.
      RUBY
    end
  end
end
