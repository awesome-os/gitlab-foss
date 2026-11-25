# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::Mcp::Handlers::CallTool, feature_category: :mcp_server do
  let(:manager) { instance_double(Mcp::Tools::Manager) }
  let(:request) { instance_double(Rack::Request) }
  let_it_be(:current_user) { create(:user) }

  subject(:handler) { described_class.new(manager) }

  describe '#invoke' do
    let(:tool_name) { 'test_tool' }
    let(:tool_lookup) { { name: tool_name, version: nil, context: nil } }
    let(:params) { { name: tool_name, arguments: { param: 'value' } } }
    let(:no_containers) do
      Mcp::Tools::Concerns::GovernanceContainerResolver::GovernanceContainerResolutionResult.none
    end

    let(:tool) do
      instance_double(Mcp::Tools::Base::BaseService,
        governed_containers: no_containers, declared_containers: no_containers, container_arguments: {})
    end

    let(:logger) { instance_double(Gitlab::Mcp::Logger) }

    before do
      allow(request).to receive(:[]).with(:id).and_return('1')
      allow(manager).to receive(:resolve_alias) { |name| name }
      allow(Gitlab::Mcp::Logger).to receive(:build).and_return(logger)
      allow(logger).to receive(:conditional_info)
      allow(tool).to receive(:is_a?).with(Mcp::Tools::Base::AggregatedService).and_return(false)
    end

    context 'when tool is found and version matches' do
      before do
        allow(manager).to receive(:get_tool).with(**tool_lookup).and_return(tool)
        allow(tool).to receive(:is_a?).with(Mcp::Tools::Base::CustomService).and_return(false)
        allow(tool).to receive(:is_a?).with(Mcp::Tools::Base::GraphqlService).and_return(false)
        allow(tool).to receive(:is_a?).with(Mcp::Tools::Base::AggregatedService).and_return(false)
        allow(tool).to receive(:execute).and_return({ content: [{ type: 'text', text: 'Success' }] })
      end

      it 'executes the tool successfully' do
        result = handler.invoke(request, params, current_user)

        expect(manager).to have_received(:get_tool).with(**tool_lookup)
        expect(tool).to have_received(:execute).with(request: request, params: params)
        expect(result).to eq({ content: [{ type: 'text', text: 'Success' }] })
      end

      context 'when the tool has a version' do
        let(:tool) do
          instance_double(Mcp::Tools::Base::ApiTool,
            governed_containers: no_containers, declared_containers: no_containers, container_arguments: {},
            version: '0.3.0')
        end

        it 'logs the version that ran and no requested version' do
          handler.invoke(request, params, current_user)

          expect(logger).to have_received(:conditional_info).with(
            current_user, hash_including(tool_version: '0.3.0', requested_tool_version: nil)
          )
        end
      end

      it 'logs the successful tool call with indexable fields and gated argument values', :aggregate_failures do
        handler.invoke(request, params, current_user)

        expect(logger).to have_received(:conditional_info).with(
          current_user,
          hash_including(
            ::Labkit::Fields::DURATION_S,
            message: 'MCP tool call',
            event_name: 'tools_call',
            ai_component: 'mcp_server',
            tool_name: tool_name,
            request_id: '1',
            tool_status: 'ok',
            argument_keys: ['param'],
            ::Labkit::Fields::GL_ROOT_NAMESPACE_ID => nil,
            expanded: { arguments: { 'param' => 'value' } }
          )
        )
        expect(logger).to have_received(:conditional_info).with(
          current_user, hash_excluding(::Labkit::Fields::ERROR_TYPE)
        )
      end

      it 'does not log client fields when the client is unknown' do
        handler.invoke(request, params, current_user)

        expect(logger).to have_received(:conditional_info).with(
          current_user, hash_excluding(:mcp_client_name, :mcp_client_version)
        )
      end

      context 'when the client identity is known' do
        let(:client_info) { Gitlab::Mcp::ClientInfo.new(name: 'Cursor', version: '1.0.0') }

        it 'logs the client name and version as indexed fields, outside expanded' do
          handler.invoke(request, params, current_user, client_info: client_info)

          expect(logger).to have_received(:conditional_info).with(
            current_user,
            hash_including(
              mcp_client_name: 'Cursor',
              mcp_client_version: '1.0.0',
              expanded: { arguments: { 'param' => 'value' } }
            )
          )
        end
      end

      it 'does not log dispatch fields for a tool that is not aggregated' do
        handler.invoke(request, params, current_user)

        expect(logger).to have_received(:conditional_info).with(
          current_user, hash_excluding(:dispatched_tool_name)
        )
      end

      context 'when the tool returns a result that is not a Hash' do
        before do
          allow(tool).to receive(:execute).and_return('Success')
        end

        it 'returns the result unchanged and logs no dispatch fields', :aggregate_failures do
          expect(handler.invoke(request, params, current_user)).to eq('Success')

          expect(logger).to have_received(:conditional_info).with(
            current_user, hash_excluding(:dispatched_tool_name)
          )
        end
      end

      context 'when the tool is aggregated' do
        let(:dispatch) { { tool_name: 'gitlab_search_in_project' } }

        before do
          allow(tool).to receive(:execute)
            .and_return({ content: [{ type: 'text', text: 'Success' }], dispatch: dispatch })
        end

        it 'logs the dispatched sub-tool as indexed fields' do
          handler.invoke(request, params, current_user)

          expect(logger).to have_received(:conditional_info).with(
            current_user,
            hash_including(dispatched_tool_name: 'gitlab_search_in_project')
          )
        end

        it 'does not return the dispatch info to the client' do
          expect(handler.invoke(request, params, current_user)).to eq({ content: [{ type: 'text', text: 'Success' }] })
        end
      end

      it 'does not add canonical_tool_name for a canonical call' do
        handler.invoke(request, params, current_user)

        expect(logger).to have_received(:conditional_info).with(
          current_user, hash_excluding(:canonical_tool_name)
        )
      end

      context 'when the tool is called by an alias' do
        let(:tool_name) { 'legacy_tool' }

        before do
          allow(manager).to receive(:resolve_alias).with('legacy_tool').and_return('test_tool')
        end

        it 'logs the name as sent alongside the canonical name' do
          handler.invoke(request, params, current_user)

          expect(logger).to have_received(:conditional_info).with(
            current_user,
            hash_including(tool_name: 'legacy_tool', canonical_tool_name: 'test_tool')
          )
        end
      end

      context 'when the caller sends the legacy id argument to a project_id tool' do
        let(:real_tool_class) do
          Class.new(Mcp::Tools::Base::BaseService) do
            def description
              'test tool'
            end

            def input_schema
              { type: 'object', properties: { project_id: { type: 'string' } } }
            end
          end
        end

        let(:tool) { real_tool_class.new(name: tool_name) }
        let(:params) { { name: tool_name, arguments: { id: 'flightjs/Flight' } }.with_indifferent_access }

        it 'renames id to project_id and logs the rewrite' do
          handler.invoke(request, params, current_user)

          expect(tool).to have_received(:execute).with(
            request: request,
            params: hash_including(arguments: { 'project_id' => 'flightjs/Flight' })
          )
          expect(logger).to have_received(:conditional_info).with(
            current_user,
            hash_including(
              argument_keys: ['id'],
              normalized_arguments: ['id->project_id']
            )
          )
        end
      end

      context 'when nothing is rewritten' do
        it 'logs no normalized_arguments field' do
          handler.invoke(request, params, current_user)

          expect(logger).to have_received(:conditional_info).with(
            current_user, hash_excluding(:normalized_arguments)
          )
        end
      end
    end

    context 'when the tool raises during execution' do
      before do
        allow(manager).to receive(:get_tool).with(**tool_lookup).and_return(tool)
        allow(tool).to receive(:is_a?).with(Mcp::Tools::Base::CustomService).and_return(false)
        allow(tool).to receive(:is_a?).with(Mcp::Tools::Base::GraphqlService).and_return(false)
        allow(tool).to receive(:is_a?).with(Mcp::Tools::Base::AggregatedService).and_return(false)
        allow(tool).to receive(:execute).and_raise(StandardError, 'boom')
      end

      it 'logs the failure and re-raises' do
        expect { handler.invoke(request, params, current_user) }.to raise_error(StandardError, 'boom')

        expect(logger).to have_received(:conditional_info).with(
          current_user,
          hash_including(
            tool_name: tool_name,
            tool_status: 'error',
            ::Labkit::Fields::ERROR_TYPE => 'StandardError',
            expanded: hash_including(::Labkit::Fields::ERROR_MESSAGE => 'boom')
          )
        )
      end

      context 'when the tool is called by an alias' do
        let(:tool_name) { 'legacy_tool' }

        before do
          allow(manager).to receive(:resolve_alias).with('legacy_tool').and_return('test_tool')
        end

        it 'records both the name as sent and the canonical name' do
          expect { handler.invoke(request, params, current_user) }.to raise_error(StandardError, 'boom')

          expect(logger).to have_received(:conditional_info).with(
            current_user,
            hash_including(tool_name: 'legacy_tool', canonical_tool_name: 'test_tool')
          )
        end
      end
    end

    context 'when the tool returns a response-level error' do
      let(:error_result) do
        {
          content: [{ type: 'text', text: 'Validation error: labels is invalid' }],
          structuredContent: {},
          isError: true,
          reason: :bad_request
        }
      end

      before do
        allow(manager).to receive(:get_tool).with(**tool_lookup).and_return(tool)
        allow(tool).to receive(:is_a?).with(Mcp::Tools::Base::CustomService).and_return(false)
        allow(tool).to receive(:is_a?).with(Mcp::Tools::Base::GraphqlService).and_return(false)
        allow(tool).to receive(:is_a?).with(Mcp::Tools::Base::AggregatedService).and_return(false)
        allow(tool).to receive(:execute).and_return(error_result)
      end

      it 'returns the error result to the agent without the internal reason' do
        result = handler.invoke(request, params, current_user)

        expect(result).to eq(error_result.except(:reason))
      end

      it 'logs the reason as tool_status and omits the exception fields', :aggregate_failures do
        handler.invoke(request, params, current_user)

        expect(logger).to have_received(:conditional_info).with(
          current_user,
          hash_including(tool_name: tool_name, tool_status: 'bad_request')
        )
        expect(logger).to have_received(:conditional_info).with(
          current_user, hash_excluding(::Labkit::Fields::ERROR_TYPE)
        )
        expect(logger).to have_received(:conditional_info).with(
          current_user,
          hash_including(expanded: hash_excluding(::Labkit::Fields::ERROR_MESSAGE))
        )
      end

      context 'when an aggregated tool dispatched the call' do
        let(:error_result) do
          {
            content: [{ type: 'text', text: '404 Not Found' }],
            structuredContent: {},
            isError: true,
            reason: :not_found,
            dispatch: { tool_name: 'update_merge_request' }
          }
        end

        it 'logs the dispatched sub-tool and returns the error without the internal keys', :aggregate_failures do
          result = handler.invoke(request, params, current_user)

          expect(result).to eq(error_result.except(:reason, :dispatch))
          expect(logger).to have_received(:conditional_info).with(
            current_user,
            hash_including(
              tool_status: 'not_found',
              dispatched_tool_name: 'update_merge_request'
            )
          )
        end
      end

      context 'when the error response carries no reason' do
        let(:error_result) do
          {
            content: [{ type: 'text', text: 'Something broke' }],
            structuredContent: {},
            isError: true
          }
        end

        it 'falls back to the generic error status' do
          handler.invoke(request, params, current_user)

          expect(logger).to have_received(:conditional_info).with(
            current_user, hash_including(tool_status: 'error')
          )
        end
      end
    end

    context 'when the tool runs database queries', :request_store do
      let(:tool_queries) { 2 }

      before do
        stub_feature_flags(omit_aggregated_db_log_fields: false)
        allow(manager).to receive(:get_tool).with(**tool_lookup).and_return(tool)
        allow(tool).to receive(:is_a?).with(Mcp::Tools::Base::CustomService).and_return(false)
        allow(tool).to receive(:is_a?).with(Mcp::Tools::Base::GraphqlService).and_return(false)
        allow(tool).to receive(:execute) do
          tool_queries.times { User.where(id: current_user.id).to_a }
          { content: [{ type: 'text', text: 'Success' }] }
        end

        User.where(id: current_user.id).to_a
      end

      it 'logs only the queries the tool ran', :aggregate_failures do
        handler.invoke(request, params, current_user)

        expect(logger).to have_received(:conditional_info).with(
          current_user,
          hash_including(db_count: tool_queries, db_main_count: tool_queries, db_duration_s: a_kind_of(Float))
        )
        expect(logger).to have_received(:conditional_info).with(
          current_user, hash_excluding(:db_write_count, :db_cached_count, :db_ci_count)
        )
      end

      it 'leaves out queries run after the tool finishes' do
        allow(handler).to receive(:track_finish_event).and_wrap_original do |method, *args, **kwargs|
          User.where(id: current_user.id).to_a
          method.call(*args, **kwargs)
        end

        handler.invoke(request, params, current_user)

        expect(logger).to have_received(:conditional_info).with(current_user, hash_including(db_count: tool_queries))
      end

      it 'sums the per-database durations into db_duration_s' do
        handler.invoke(request, params, current_user)

        expect(logger).to have_received(:conditional_info) do |_user, fields|
          expect(fields[:db_duration_s]).to eq(fields[:db_main_duration_s])
        end
      end

      context 'when aggregated DB log fields are omitted' do
        before do
          stub_feature_flags(omit_aggregated_db_log_fields: true)
        end

        it 'logs the per-database counters and the summed duration', :aggregate_failures do
          handler.invoke(request, params, current_user)

          expect(logger).to have_received(:conditional_info).with(
            current_user, hash_including(db_main_count: tool_queries, db_duration_s: a_kind_of(Float))
          )
          expect(logger).to have_received(:conditional_info).with(current_user, hash_excluding(:db_count))
        end
      end

      context 'when the tool raises after running queries' do
        before do
          allow(tool).to receive(:execute) do
            User.where(id: current_user.id).to_a
            raise StandardError, 'boom'
          end
        end

        it 'logs the queries on the error line' do
          expect { handler.invoke(request, params, current_user) }.to raise_error(StandardError, 'boom')

          expect(logger).to have_received(:conditional_info).with(
            current_user, hash_including(tool_status: 'error', db_count: 1)
          )
        end
      end

      context 'when the tool returns a response-level error after running queries' do
        before do
          allow(tool).to receive(:execute) do
            User.where(id: current_user.id).to_a
            { content: [{ type: 'text', text: 'Invalid' }], isError: true, reason: :bad_request }
          end
        end

        it 'logs the queries on the error line' do
          handler.invoke(request, params, current_user)

          expect(logger).to have_received(:conditional_info).with(
            current_user, hash_including(tool_status: 'bad_request', db_count: 1)
          )
        end
      end

      context 'when the tool runs a transaction' do
        before do
          allow(tool).to receive(:execute) do
            ApplicationRecord.transaction(requires_new: true) { User.where(id: current_user.id).to_a }
            { content: [{ type: 'text', text: 'Success' }] }
          end
        end

        it 'logs the transaction count and duration but not the running maximum', :aggregate_failures do
          handler.invoke(request, params, current_user)

          expect(logger).to have_received(:conditional_info).with(
            current_user, hash_including(db_main_txn_count: 1, db_main_txn_duration_s: a_kind_of(Float))
          )
          expect(logger).to have_received(:conditional_info).with(
            current_user, hash_excluding(:db_main_txn_max_duration_s)
          )
        end
      end

      context 'when the tool runs no queries' do
        let(:tool_queries) { 0 }

        it 'logs no database fields' do
          handler.invoke(request, params, current_user)

          expect(logger).to have_received(:conditional_info).with(
            current_user, hash_excluding(:db_count, :db_main_count, :db_duration_s)
          )
        end
      end
    end

    context 'when the tool makes Gitaly calls', :request_store do
      let(:gitaly_calls) { 3 }
      let(:gitaly_duration) { 0.5 }

      def fake_gitaly_calls
        Gitlab::SafeRequestStore['gitaly_call_actual'] = Gitlab::GitalyClient.get_request_count + gitaly_calls
        Gitlab::SafeRequestStore[:gitaly_query_time] = Gitlab::GitalyClient.query_time + gitaly_duration
      end

      before do
        allow(manager).to receive(:get_tool).with(**tool_lookup).and_return(tool)
        allow(tool).to receive(:is_a?).with(Mcp::Tools::Base::CustomService).and_return(false)
        allow(tool).to receive(:is_a?).with(Mcp::Tools::Base::GraphqlService).and_return(false)
        allow(tool).to receive(:execute) do
          fake_gitaly_calls
          { content: [{ type: 'text', text: 'Success' }] }
        end
      end

      it 'logs the Gitaly calls and duration' do
        handler.invoke(request, params, current_user)

        expect(logger).to have_received(:conditional_info).with(
          current_user, hash_including(gitaly_calls: gitaly_calls, gitaly_duration_s: gitaly_duration)
        )
      end

      context 'when the request made Gitaly calls before the tool ran' do
        before do
          Gitlab::SafeRequestStore['gitaly_call_actual'] = 2
          Gitlab::SafeRequestStore[:gitaly_query_time] = 0.1
        end

        it 'logs only the Gitaly calls the tool made' do
          handler.invoke(request, params, current_user)

          expect(logger).to have_received(:conditional_info).with(
            current_user, hash_including(gitaly_calls: gitaly_calls, gitaly_duration_s: gitaly_duration)
          )
        end
      end

      context 'when the tool raises after making Gitaly calls' do
        before do
          allow(tool).to receive(:execute) do
            fake_gitaly_calls
            raise StandardError, 'boom'
          end
        end

        it 'logs the Gitaly fields on the error line' do
          expect { handler.invoke(request, params, current_user) }.to raise_error(StandardError, 'boom')

          expect(logger).to have_received(:conditional_info).with(
            current_user,
            hash_including(tool_status: 'error', gitaly_calls: gitaly_calls, gitaly_duration_s: gitaly_duration)
          )
        end
      end

      context 'when the tool returns a response-level error after making Gitaly calls' do
        before do
          allow(tool).to receive(:execute) do
            fake_gitaly_calls
            { content: [{ type: 'text', text: 'Invalid' }], isError: true, reason: :bad_request }
          end
        end

        it 'logs the Gitaly fields on the error line' do
          handler.invoke(request, params, current_user)

          expect(logger).to have_received(:conditional_info).with(
            current_user,
            hash_including(
              tool_status: 'bad_request', gitaly_calls: gitaly_calls, gitaly_duration_s: gitaly_duration
            )
          )
        end
      end

      context 'when the tool makes no Gitaly calls' do
        before do
          allow(tool).to receive(:execute).and_return({ content: [{ type: 'text', text: 'Success' }] })
        end

        it 'logs no Gitaly fields' do
          handler.invoke(request, params, current_user)

          expect(logger).to have_received(:conditional_info).with(
            current_user, hash_excluding(:gitaly_calls, :gitaly_duration_s)
          )
        end
      end
    end

    context 'when tool is a custom service' do
      let(:access_token) { instance_double(PersonalAccessToken) }
      let(:request_context) { Mcp::Tools::RequestContext.new(current_user: current_user, access_token: access_token) }
      let(:tool_lookup) { { name: tool_name, version: nil, context: request_context } }
      let(:custom_tool) do
        instance_double(Mcp::Tools::Base::CustomService,
          governed_containers: no_containers, declared_containers: no_containers, container_arguments: {})
      end

      before do
        allow(manager).to receive(:get_tool).with(**tool_lookup).and_return(custom_tool)
        allow(custom_tool).to receive(:is_a?).with(Mcp::Tools::Base::CustomService).and_return(true)
        allow(custom_tool).to receive(:is_a?).with(Mcp::Tools::Base::GraphqlService).and_return(false)
        allow(custom_tool).to receive(:is_a?).with(Mcp::Tools::Base::AggregatedService).and_return(false)
        allow(custom_tool).to receive(:set_cred)
        allow(custom_tool).to receive(:execute).and_return({ content: [{ type: 'text', text: 'Success' }] })
      end

      it 'sets credentials before executing' do
        result = handler.invoke(request, params, current_user, context: request_context)

        expect(custom_tool).to have_received(:set_cred).with(current_user: current_user, access_token: access_token)
        expect(custom_tool).to have_received(:execute).with(request: request, params: params)
        expect(result).to eq({ content: [{ type: 'text', text: 'Success' }] })
      end
    end

    context 'when tool is a graphql service' do
      let(:access_token) { instance_double(PersonalAccessToken) }
      let(:request_context) { Mcp::Tools::RequestContext.new(current_user: current_user, access_token: access_token) }
      let(:tool_lookup) { { name: tool_name, version: nil, context: request_context } }
      let(:graphql_tool) do
        instance_double(Mcp::Tools::Base::GraphqlService,
          governed_containers: no_containers, declared_containers: no_containers, container_arguments: {})
      end

      before do
        allow(manager).to receive(:get_tool).with(**tool_lookup).and_return(graphql_tool)
        allow(graphql_tool).to receive(:is_a?).with(Mcp::Tools::Base::CustomService).and_return(false)
        allow(graphql_tool).to receive(:is_a?).with(Mcp::Tools::Base::GraphqlService).and_return(true)
        allow(graphql_tool).to receive(:is_a?).with(Mcp::Tools::Base::AggregatedService).and_return(false)
        allow(graphql_tool).to receive(:set_cred)
        allow(graphql_tool).to receive(:execute).and_return({ content: [{ type: 'text', text: 'Success' }] })
      end

      it 'sets credentials before executing' do
        result = handler.invoke(request, params, current_user, context: request_context)

        expect(graphql_tool).to have_received(:set_cred).with(current_user: current_user, access_token: access_token)
        expect(graphql_tool).to have_received(:execute).with(request: request, params: params)
        expect(result).to eq({ content: [{ type: 'text', text: 'Success' }] })
      end
    end

    context 'when tool is an aggregated service' do
      let(:aggregated_tool) do
        instance_double(Mcp::Tools::Base::AggregatedService,
          governed_containers: no_containers, declared_containers: no_containers, container_arguments: {})
      end

      before do
        allow(manager).to receive(:get_tool).with(**tool_lookup).and_return(aggregated_tool)
        allow(aggregated_tool).to receive(:is_a?).with(Mcp::Tools::Base::CustomService).and_return(false)
        allow(aggregated_tool).to receive(:is_a?).with(Mcp::Tools::Base::GraphqlService).and_return(false)
        allow(aggregated_tool).to receive(:is_a?).with(Mcp::Tools::Base::AggregatedService).and_return(true)
        allow(aggregated_tool).to receive(:set_cred)
        allow(aggregated_tool).to receive(:execute).and_return({ content: [{ type: 'text', text: 'Success' }] })
      end

      it 'sets credentials before executing' do
        result = handler.invoke(request, params, current_user)

        expect(aggregated_tool).to have_received(:set_cred).with(current_user: current_user)
        expect(aggregated_tool).to have_received(:execute).with(request: request, params: params)
        expect(result).to eq({ content: [{ type: 'text', text: 'Success' }] })
      end
    end

    context 'when tool is not found' do
      before do
        allow(manager).to receive(:get_tool).with(**tool_lookup)
          .and_raise(Mcp::Tools::Manager::ToolNotFoundError.new(tool_name))
      end

      it 'raises ArgumentError' do
        expect { handler.invoke(request, params, current_user) }
          .to raise_error(ArgumentError, "Tool '#{tool_name}' not found.")
      end

      it 'logs the failed tool call' do
        expect { handler.invoke(request, params, current_user) }.to raise_error(ArgumentError)

        expect(logger).to have_received(:conditional_info).with(
          current_user,
          hash_including(
            tool_name: tool_name,
            tool_status: 'not_found',
            ::Labkit::Fields::ERROR_TYPE => 'Mcp::Tools::Manager::ToolNotFoundError'
          )
        )
      end

      it 'logs no database fields', :request_store do
        User.where(id: current_user.id).to_a

        expect { handler.invoke(request, params, current_user) }.to raise_error(ArgumentError)

        expect(logger).to have_received(:conditional_info).with(
          current_user, hash_excluding(:db_count, :db_main_count, :db_duration_s)
        )
      end

      it 'logs no Gitaly fields, even when the request holds Gitaly counters', :request_store do
        Gitlab::SafeRequestStore['gitaly_call_actual'] = 2
        Gitlab::SafeRequestStore[:gitaly_query_time] = 0.1

        expect { handler.invoke(request, params, current_user) }.to raise_error(ArgumentError)

        expect(logger).to have_received(:conditional_info).with(
          current_user, hash_excluding(:gitaly_calls, :gitaly_duration_s)
        )
      end
    end

    def tool_requirements_meta(requirements)
      { _meta: { 'com.gitlab/tool_requirements' => requirements } }
    end

    context 'when the client pins a tool version' do
      let(:params) do
        { name: tool_name, **tool_requirements_meta({ tool_name => '0.2.0' }), arguments: { param: 'value' } }
      end

      before do
        allow(manager).to receive(:get_tool).with(**tool_lookup, version: '0.2.0').and_return(tool)
        allow(tool).to receive(:is_a?).with(Mcp::Tools::Base::CustomService).and_return(false)
        allow(tool).to receive(:is_a?).with(Mcp::Tools::Base::GraphqlService).and_return(false)
        allow(tool).to receive(:is_a?).with(Mcp::Tools::Base::AggregatedService).and_return(false)
        allow(tool).to receive(:execute).and_return({ content: [{ type: 'text', text: 'Success' }] })
      end

      it 'resolves the pinned version instead of the latest' do
        result = handler.invoke(request, params, current_user)

        expect(manager).to have_received(:get_tool).with(**tool_lookup, version: '0.2.0')
        expect(result).to eq({ content: [{ type: 'text', text: 'Success' }] })
      end

      context 'when the tool has a version' do
        let(:tool) do
          instance_double(Mcp::Tools::Base::ApiTool,
            governed_containers: no_containers, declared_containers: no_containers, container_arguments: {},
            version: '0.2.0')
        end

        it 'logs both the requested and the resolved version' do
          handler.invoke(request, params, current_user)

          expect(logger).to have_received(:conditional_info).with(
            current_user, hash_including(tool_version: '0.2.0', requested_tool_version: '0.2.0')
          )
        end
      end

      context 'when the requirement is keyed by the prefixed name the client was served' do
        let(:params) do
          {
            name: "gitlab_#{tool_name}",
            **tool_requirements_meta({ "gitlab_#{tool_name}" => '0.2.0' }),
            arguments: { param: 'value' }
          }
        end

        it 'resolves the pinned version' do
          handler.invoke(request, params, current_user, tool_name_prefix: 'gitlab_')

          expect(manager).to have_received(:get_tool).with(**tool_lookup, version: '0.2.0')
        end
      end

      context 'when the tool is called by an alias and the requirement uses the canonical name' do
        let(:params) do
          { name: 'legacy_tool', **tool_requirements_meta({ tool_name => '0.2.0' }), arguments: { param: 'value' } }
        end

        before do
          allow(manager).to receive(:resolve_alias).with('legacy_tool').and_return(tool_name)
          allow(manager).to receive(:get_tool)
            .with(**tool_lookup, name: 'legacy_tool', version: '0.2.0').and_return(tool)
        end

        it 'resolves the pinned version' do
          handler.invoke(request, params, current_user)

          expect(manager).to have_received(:get_tool).with(**tool_lookup, name: 'legacy_tool', version: '0.2.0')
        end
      end

      context 'when the requirements name a different tool' do
        let(:params) do
          { name: tool_name, **tool_requirements_meta({ 'other_tool' => '0.2.0' }), arguments: { param: 'value' } }
        end

        before do
          allow(manager).to receive(:get_tool).with(**tool_lookup).and_return(tool)
        end

        it 'falls back to the latest version' do
          handler.invoke(request, params, current_user)

          expect(manager).to have_received(:get_tool).with(**tool_lookup)
        end
      end

      context 'when _meta has no tool requirements' do
        let(:params) { { name: tool_name, _meta: { 'progressToken' => 'abc' }, arguments: { param: 'value' } } }

        before do
          allow(manager).to receive(:get_tool).with(**tool_lookup).and_return(tool)
        end

        it 'resolves the latest version' do
          handler.invoke(request, params, current_user)

          expect(manager).to have_received(:get_tool).with(**tool_lookup)
        end
      end
    end

    context 'when the pinned version is not registered' do
      let(:params) do
        { name: tool_name, **tool_requirements_meta({ tool_name => '9.9.9' }), arguments: { param: 'value' } }
      end

      before do
        allow(manager).to receive(:get_tool).with(**tool_lookup, version: '9.9.9')
          .and_raise(Mcp::Tools::Manager::VersionNotFoundError.new(tool_name, '9.9.9', %w[0.1.0 0.2.0]))
      end

      it 'raises a recoverable error naming the supported versions' do
        expect { handler.invoke(request, params, current_user) }.to raise_error(
          ArgumentError,
          "Tool '#{tool_name}' version '9.9.9' not found. Available versions: 0.1.0, 0.2.0"
        )
      end

      it 'logs the failed tool call' do
        expect { handler.invoke(request, params, current_user) }.to raise_error(ArgumentError)

        expect(logger).to have_received(:conditional_info).with(
          current_user,
          hash_including(
            tool_status: 'bad_request',
            requested_tool_version: '9.9.9',
            ::Labkit::Fields::ERROR_TYPE => 'Mcp::Tools::Manager::VersionNotFoundError'
          )
        )
      end
    end

    context 'when the pin is a range rather than an exact version' do
      let(:params) do
        { name: tool_name, **tool_requirements_meta({ tool_name => '^0.1.0' }), arguments: { param: 'value' } }
      end

      before do
        allow(manager).to receive(:get_tool).with(**tool_lookup, version: '^0.1.0')
          .and_raise(Mcp::Tools::Manager::InvalidVersionFormatError.new('^0.1.0'))
      end

      it 'raises a recoverable error rather than resolving the range' do
        expect { handler.invoke(request, params, current_user) }
          .to raise_error(ArgumentError, 'Invalid semantic version format: ^0.1.0.')
      end

      it 'logs the failed tool call as a bad request' do
        expect { handler.invoke(request, params, current_user) }.to raise_error(ArgumentError)

        expect(logger).to have_received(:conditional_info).with(
          current_user, hash_including(tool_status: 'bad_request', requested_tool_version: '^0.1.0')
        )
      end
    end

    context 'when the pin is blank' do
      where(:version) { ['', ' '] }

      with_them do
        let(:params) { { name: tool_name, **tool_requirements_meta({ tool_name => version }), arguments: {} } }

        before do
          allow(manager).to receive(:get_tool).with(**tool_lookup, version: version)
            .and_raise(Mcp::Tools::Manager::InvalidVersionFormatError.new(version))
        end

        it 'passes the blank pin on to be rejected rather than serving the latest version' do
          expect { handler.invoke(request, params, current_user) }.to raise_error(ArgumentError)

          expect(manager).to have_received(:get_tool).with(**tool_lookup, version: version)
        end
      end
    end

    context 'when the pin is longer than the log field allows' do
      let(:version) { '1' * 300 }
      let(:params) { { name: tool_name, **tool_requirements_meta({ tool_name => version }), arguments: {} } }

      before do
        allow(manager).to receive(:get_tool).with(**tool_lookup, version: version)
          .and_raise(Mcp::Tools::Manager::InvalidVersionFormatError.new(version))
      end

      it 'logs the pin truncated to 255 characters' do
        expect { handler.invoke(request, params, current_user) }.to raise_error(ArgumentError)

        expect(logger).to have_received(:conditional_info).with(
          current_user, hash_including(requested_tool_version: version.truncate(255))
        )
      end
    end

    context 'when the tool requirements are not an object' do
      let(:params) { { name: tool_name, **tool_requirements_meta('0.2.0'), arguments: { param: 'value' } } }

      it 'raises a recoverable error rather than silently serving the latest version' do
        expect { handler.invoke(request, params, current_user) }.to raise_error(
          ArgumentError, 'com.gitlab/tool_requirements must be an object mapping tool names to exact versions'
        )
      end

      it 'logs the failed tool call as a bad request' do
        expect { handler.invoke(request, params, current_user) }.to raise_error(ArgumentError)

        expect(logger).to have_received(:conditional_info)
          .with(current_user, hash_including(tool_status: 'bad_request'))
      end
    end

    context 'when the pinned version is not a string' do
      where(:version) { [nil, true, false, 1, 0.1] }

      with_them do
        let(:params) { { name: tool_name, **tool_requirements_meta({ tool_name => version }), arguments: {} } }

        it 'raises a recoverable error' do
          expect { handler.invoke(request, params, current_user) }
            .to raise_error(ArgumentError, 'com.gitlab/tool_requirements versions must be strings')
        end

        it 'logs the version as sent, as a bad request' do
          expect { handler.invoke(request, params, current_user) }.to raise_error(ArgumentError)

          expect(logger).to have_received(:conditional_info).with(
            current_user, hash_including(tool_status: 'bad_request', requested_tool_version: version.to_json)
          )
        end
      end
    end

    context 'when handling route status metadata' do
      let(:status_key) { Mcp::Tools::Base::ApiTool::ROUTE_STATUS_KEY }
      let(:success_result) { { content: [{ type: 'text', text: 'Success' }], isError: false } }

      before do
        allow(manager).to receive(:get_tool).with(**tool_lookup).and_return(tool)
        allow(tool).to receive(:is_a?).and_return(false)
        allow(tool).to receive(:set_cred)
      end

      context 'when a route-backed tool returns the HTTP status of its route' do
        before do
          allow(tool).to receive(:execute).and_return(success_result.merge(status_key => 201))
        end

        it 'logs the HTTP status next to the unchanged tool_status', :aggregate_failures do
          handler.invoke(request, params, current_user)

          expect(logger).to have_received(:conditional_info).with(
            current_user,
            hash_including(tool_status: 'ok', ::Labkit::Fields::HTTP_STATUS_CODE => 201)
          )
        end

        it 'does not leak the internal metadata into the result' do
          expect(handler.invoke(request, params, current_user)).to eq(success_result)
        end
      end

      context 'when a route-backed tool returns an error response' do
        let(:error_result) do
          Mcp::Tools::Base::Response.error('404 Not Found', {}, reason: :not_found).merge(status_key => 404)
        end

        before do
          allow(tool).to receive(:execute).and_return(error_result)
        end

        it 'logs the actual HTTP status and the categorized tool_status', :aggregate_failures do
          handler.invoke(request, params, current_user)

          expect(logger).to have_received(:conditional_info).with(
            current_user,
            hash_including(tool_status: 'not_found', ::Labkit::Fields::HTTP_STATUS_CODE => 404)
          )
        end

        it 'strips the internal metadata and the reason from the result', :aggregate_failures do
          result = handler.invoke(request, params, current_user)

          expect(result).not_to include(status_key, :reason)
          expect(result[:isError]).to be(true)
        end
      end

      context 'when a route-backed tool also returns dispatch metadata' do
        let(:dispatch_key) { described_class::DISPATCH_KEY }

        before do
          allow(tool).to receive(:execute)
            .and_return(success_result.merge(status_key => 200, dispatch_key => { tool_name: 'inner_tool' }))
        end

        it 'logs both and strips both from the result', :aggregate_failures do
          result = handler.invoke(request, params, current_user)

          expect(result).to eq(success_result)
          expect(logger).to have_received(:conditional_info).with(
            current_user,
            hash_including(dispatched_tool_name: 'inner_tool', ::Labkit::Fields::HTTP_STATUS_CODE => 200)
          )
        end
      end

      context 'when the tool does not run a REST route' do
        before do
          allow(tool).to receive(:execute).and_return(success_result)
        end

        it 'does not log a status', :aggregate_failures do
          handler.invoke(request, params, current_user)

          expect(logger).to have_received(:conditional_info).with(
            current_user, hash_including(tool_status: 'ok')
          )
          expect(logger).to have_received(:conditional_info).with(
            current_user, hash_excluding(::Labkit::Fields::HTTP_STATUS_CODE)
          )
        end
      end
    end
  end
end
