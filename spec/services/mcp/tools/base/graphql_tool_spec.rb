# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mcp::Tools::Base::GraphqlTool, feature_category: :mcp_server do
  let_it_be(:user) { create(:user) }
  let(:params) { { project_path: 'gitlab-org/gitlab' } }

  # Create a test implementation with versioning
  let(:test_tool_class) do
    Class.new(described_class) do
      register_version '1.0.0', {
        operation_name: 'testMutation',
        graphql_operation: <<~GRAPHQL
          mutation($input: TestInput!) {
            testMutation(input: $input) {
              result { id }
              errors
            }
          }
        GRAPHQL
      }

      register_version '2.0.0', {
        operation_name: 'testMutation',
        graphql_operation: <<~GRAPHQL
          mutation($input: TestInput!) {
            testMutation(input: $input) {
              result { id title description }
              errors
            }
          }
        GRAPHQL
      }

      def build_variables
        { input: { projectPath: params[:project_path] } }
      end

      private

      def build_variables_v2_0_0
        {
          input: {
            projectPath: params[:project_path],
            includeArchived: params[:include_archived]
          }.compact
        }
      end
    end
  end

  let(:tool) { test_tool_class.new(current_user: user, params: params, access_token: nil) }

  # Registers only graphql_operation, so operation_name is inferred from the response root field.
  let(:inferred_tool_class) do
    Class.new(described_class) do
      register_version '1.0.0', {
        graphql_operation: <<~GRAPHQL
          query($isProject: Boolean!) {
            project(fullPath: "gitlab-org/gitlab") @include(if: $isProject) { id }
            group(fullPath: "gitlab-org") @skip(if: $isProject) { id }
          }
        GRAPHQL
      }

      def build_variables
        {}
      end
    end
  end

  let(:inferred_tool) { inferred_tool_class.new(current_user: user, params: params, access_token: nil) }

  describe '#resource_access_denied?' do
    subject(:access_denied) { tool.send(:resource_access_denied?, result) }

    let(:access_error) { Gitlab::Graphql::Authorize::AuthorizeResource::RESOURCE_ACCESS_ERROR }

    context 'when an access error is mixed with other errors' do
      let(:result) { { 'errors' => ['Operation failed', nil, { 'message' => access_error }] } }

      it 'detects the access denial' do
        expect(access_denied).to be(true)
      end
    end

    context 'when there are only unrelated errors' do
      let(:result) { { 'errors' => ['Operation failed', nil, {}, { 'message' => 'Invalid input' }] } }

      it 'does not classify them as an access denial' do
        expect(access_denied).to be(false)
      end
    end

    context 'when there are no errors' do
      let(:result) { {} }

      it 'does not report an access denial' do
        expect(access_denied).to be(false)
      end
    end

    context 'when the errors list is empty' do
      let(:result) { { 'errors' => [] } }

      it 'does not report an access denial' do
        expect(access_denied).to be(false)
      end
    end
  end

  describe '.load_graphql' do
    it 'reads a real query file and returns a frozen string' do
      operation = described_class.load_graphql('notes/create_note.mutation.graphql')

      expect(operation).to include('mutation createNote')
      expect(operation).to be_frozen
    end

    it 'appends the fragments the query imports' do
      operation = described_class.load_graphql('work_items/get_work_item.query.graphql')

      expect(operation).to include('query getWorkItem(', 'fragment WorkItemEditionWidgets on WorkItemWidget')
    end

    it 'raises Errno::ENOENT for a missing path' do
      expect { described_class.load_graphql('notes/does_not_exist.query.graphql') }
        .to raise_error(Errno::ENOENT)
    end
  end

  describe '#initialize' do
    it 'sets current_user and params' do
      expect(tool.current_user).to eq(user)
      expect(tool.params).to eq(params)
    end

    it 'initializes with latest version by default' do
      expect(tool.version).to eq('2.0.0')
    end

    context 'when version is specified' do
      let(:tool) { test_tool_class.new(current_user: user, params: params, version: '1.0.0', access_token: nil) }

      it 'uses the specified version' do
        expect(tool.version).to eq('1.0.0')
      end
    end

    context 'when invalid version is specified' do
      it 'raises ArgumentError' do
        expect do
          test_tool_class.new(current_user: user, params: params, version: '99.99.99', access_token: nil)
        end.to raise_error(ArgumentError, 'Version 99.99.99 not found. Available: 1.0.0, 2.0.0')
      end
    end

    context 'when access_token is omitted' do
      it 'raises ArgumentError' do
        expect do
          test_tool_class.new(current_user: user, params: params)
        end.to raise_error(ArgumentError, /missing keyword: :access_token/)
      end
    end
  end

  describe '#graphql_operation' do
    context 'when not implemented in subclass and not in version metadata' do
      let(:tool_without_operation) do
        Class.new(described_class) do
          register_version '1.0.0', { operation_name: 'test' }

          def build_variables
            {}
          end
        end.new(current_user: user, params: params, access_token: nil)
      end

      it 'raises NotImplementedError' do
        expect { tool_without_operation.graphql_operation }.to raise_error(NotImplementedError)
      end
    end

    context 'when defined in version metadata' do
      it 'returns the GraphQL operation from metadata' do
        operation = tool.graphql_operation

        expect(operation).to include('testMutation')
        expect(operation).to include('result { id title description }')
      end
    end
  end

  describe '#operation_name' do
    context 'when not defined in version metadata' do
      let(:tool_without_operation_name) do
        Class.new(described_class) do
          register_version '1.0.0', { graphql_operation: 'query { test }' }

          def build_variables
            {}
          end
        end.new(current_user: user, params: params, access_token: nil)
      end

      it 'returns nil' do
        expect(tool_without_operation_name.operation_name).to be_nil
      end
    end

    context 'when defined in version metadata' do
      it 'returns the operation name from metadata' do
        expect(tool.operation_name).to eq('testMutation')
      end
    end
  end

  describe '#operation_data' do
    context 'when operation_name is explicit' do
      it 'returns the payload under that key even when another key is present' do
        result = { 'data' => { 'testMutation' => { 'x' => 1 }, 'other' => { 'y' => 2 } } }

        expect(tool.send(:operation_data, result)).to eq({ 'x' => 1 })
      end
    end

    context 'when operation_name is not set and there is a single root field' do
      it 'infers the root field' do
        result = { 'data' => { 'project' => { 'x' => 1 } } }

        expect(inferred_tool.send(:operation_data, result)).to eq({ 'x' => 1 })
      end
    end

    context 'when the query uses @skip/@include branches' do
      it 'infers the root field that was not skipped' do
        # GraphQL omits the skipped field from data entirely, so only one key remains.
        result = { 'data' => { 'group' => { 'x' => 1 } } }

        expect(inferred_tool.send(:operation_data, result)).to eq({ 'x' => 1 })
      end
    end

    context 'when every branch is skipped' do
      it 'returns nil' do
        result = { 'data' => {} }

        expect(inferred_tool.send(:operation_data, result)).to be_nil
      end
    end

    context 'when data is nil' do
      it 'returns nil' do
        result = { 'data' => nil }

        expect(inferred_tool.send(:operation_data, result)).to be_nil
      end
    end

    context 'when data is missing' do
      it 'returns nil' do
        result = {}

        expect(inferred_tool.send(:operation_data, result)).to be_nil
      end
    end

    context 'when the root field is present but null' do
      it 'returns nil' do
        result = { 'data' => { 'project' => nil } }

        expect(inferred_tool.send(:operation_data, result)).to be_nil
      end
    end

    context 'when there are multiple root fields and no explicit operation_name' do
      it 'raises MultipleRootFieldsError naming the root fields' do
        result = { 'data' => { 'project' => { 'x' => 1 }, 'group' => { 'y' => 2 } } }

        expect { inferred_tool.send(:operation_data, result) }
          .to raise_error(
            Mcp::Tools::Base::GraphqlTool::MultipleRootFieldsError,
            'Query returned multiple root fields (project, group); set operation_name'
          )
      end
    end
  end

  describe '#build_variables' do
    context 'when not implemented in subclass' do
      let(:tool_without_variables) do
        Class.new(described_class) do
          register_version '1.0.0', {
            operation_name: 'test',
            graphql_operation: 'query { test }'
          }
        end.new(current_user: user, params: params, access_token: nil)
      end

      it 'raises NotImplementedError' do
        expect { tool_without_variables.build_variables }
          .to raise_error(NotImplementedError, 'build_variables must be implemented')
      end
    end

    context 'when implemented in subclass' do
      it 'returns the variables' do
        expect(tool.build_variables).to eq({ input: { projectPath: 'gitlab-org/gitlab' } })
      end
    end
  end

  describe '#icons' do
    it 'returns icons array with dark and light themes' do
      icons = tool.icons

      expect(icons).to be_an(Array)
      expect(icons.length).to eq(2)
      expect(icons.first).to include(:mimeType, :src, :theme)
      expect(icons.first[:theme]).to eq('dark')
      expect(icons.last[:theme]).to eq('light')
    end
  end

  describe '#resource_not_found_error_for_result' do
    it 'delegates to the existing hook when operation data is missing' do
      error = tool.send(:resource_not_found_error_for_result, { 'data' => { 'testMutation' => nil } })

      expect(error[:isError]).to be(true)
      expect(error[:content].first[:text]).to eq('Operation returned no data')
    end

    it 'returns nil when operation data exists' do
      result = tool.send(:resource_not_found_error_for_result, { 'data' => { 'testMutation' => {} } })

      expect(result).to be_nil
    end

    context 'when operation_name is inferred' do
      it 'returns a not-found error when every root field is missing' do
        error = inferred_tool.send(:resource_not_found_error_for_result, { 'data' => {} })

        expect(error[:isError]).to be(true)
        expect(error[:content].first[:text]).to eq('Operation returned no data')
      end

      it 'returns nil when the inferred root field has data' do
        result = inferred_tool.send(:resource_not_found_error_for_result, { 'data' => { 'project' => {} } })

        expect(result).to be_nil
      end
    end
  end

  describe '#execute' do
    let(:graphql_result) do
      {
        'data' => {
          'testMutation' => {
            'result' => { 'id' => 'gid://gitlab/Test/1', 'title' => 'Test', 'description' => 'Description' },
            'errors' => []
          }
        }
      }
    end

    let(:operation_data) do
      {
        'result' => { 'id' => 'gid://gitlab/Test/1', 'title' => 'Test', 'description' => 'Description' },
        'errors' => []
      }
    end

    let(:formatted_content) do
      [{ type: 'text', text: Gitlab::Json.dump(operation_data) }]
    end

    let(:success_response) { instance_double(Mcp::Tools::Base::Response) }

    before do
      allow(GitlabSchema).to receive(:execute).and_return(graphql_result)
      allow(::Mcp::Tools::Base::Response).to receive(:success).and_return(success_response)
      allow(::Mcp::Tools::Base::Response).to receive(:error)
    end

    it 'executes GraphQL mutation with correct context' do
      tool.execute

      expect(GitlabSchema).to have_received(:execute).with(
        anything,
        variables: { input: { projectPath: 'gitlab-org/gitlab' } },
        context: {
          current_user: user,
          access_token: nil,
          request: nil,
          is_sessionless_user: false,
          mcp_tool: nil
        }
      )
    end

    context 'with an access token' do
      let(:access_token) { build_stubbed(:personal_access_token, user: user) }
      let(:tool) { test_tool_class.new(current_user: user, params: params, access_token: access_token) }

      it 'passes the access token in the GraphQL context' do
        tool.execute

        expect(GitlabSchema).to have_received(:execute)
          .with(anything, variables: anything, context: hash_including(access_token: access_token))
      end
    end

    context 'with a request' do
      let(:request) { instance_double(ActionDispatch::Request) }
      let(:tool) { test_tool_class.new(current_user: user, params: params, access_token: nil, request: request) }

      it 'passes the request in the GraphQL context' do
        tool.execute

        expect(GitlabSchema).to have_received(:execute)
          .with(anything, variables: anything, context: hash_including(request: request))
      end
    end

    context 'when the granular token is denied during execution' do
      let(:access_token) { build_stubbed(:personal_access_token, user: user) }
      let(:tool) { test_tool_class.new(current_user: user, params: params, access_token: access_token) }
      let(:denied_result) { { 'data' => { 'testMutation' => nil } } }

      before do
        allow(::Mcp::Tools::Base::Response).to receive(:error).and_call_original
        allow(GitlabSchema).to receive(:execute) do
          ::Current.add_granular_denied_permissions([:read_project])
          denied_result
        end
      end

      it 'returns an access denied error naming the missing permissions' do
        expect(tool.execute).to include(
          isError: true,
          reason: :unauthorized,
          content: [{
            type: 'text',
            text: 'Access denied: This operation requires a fine-grained personal access token ' \
              'with the following permissions: [Project: Read].'
          }]
        )
      end

      context 'when permissions were denied earlier in the request' do
        before do
          ::Current.add_granular_denied_permissions(%i[read_project read_code])
        end

        it 'still reports the permission denied during this execution' do
          expect(tool.execute).to include(isError: true, reason: :unauthorized)
        end

        it 'keeps the earlier denials recorded' do
          tool.execute

          expect(::Current.granular_denied_permissions).to contain_exactly(:read_project, :read_code)
        end
      end

      context 'when the tool error is not a not found or unauthorized error' do
        let(:denied_result) { { 'errors' => [{ 'message' => 'Access denied: project permissions' }] } }

        it 'returns the tool error' do
          expect(tool.execute).to include(
            isError: true,
            content: [{ type: 'text', text: 'Access denied: project permissions' }]
          )
        end
      end

      context 'when the tool still returns data' do
        let(:denied_result) { graphql_result }

        it 'returns the successful response' do
          expect(tool.execute).to eq(success_response)
        end
      end
    end

    it 'uses version-specific GraphQL operation' do
      tool.execute

      expect(GitlabSchema).to have_received(:execute) do |operation, **_options|
        expect(operation).to include('result { id title description }')
      end
    end

    it 'returns success response' do
      result = tool.execute

      expect(::Mcp::Tools::Base::Response).to have_received(:success).with(
        formatted_content,
        operation_data
      )
      expect(result).to eq(success_response)
    end

    context 'when GraphQL returns syntax errors' do
      let(:graphql_result) do
        {
          'errors' => [
            { 'message' => 'Syntax error' }
          ]
        }
      end

      let(:error_response) { instance_double(Mcp::Tools::Base::Response) }

      before do
        allow(::Mcp::Tools::Base::Response).to receive(:error).and_return(error_response)
      end

      it 'returns error response' do
        result = tool.execute

        expect(::Mcp::Tools::Base::Response).to have_received(:error).with('Syntax error')
        expect(result).to eq(error_response)
      end
    end

    context 'when GraphQL returns a rate limited error' do
      let(:error) { ::Gitlab::Graphql::Errors::RateLimitedError.new('Search throttled', limit: :search_rate_limit) }
      let(:graphql_result) { { 'errors' => [error.to_h] } }

      before do
        allow(::Mcp::Tools::Base::Response).to receive(:error).and_call_original
      end

      it 'returns a structured rate limited error' do
        expect(tool.execute).to include(
          isError: true,
          structuredContent: {
            error: {
              type: 'rate_limited', retry_after_seconds: 60, limit: 'search_rate_limit', message: 'Search throttled'
            }
          }
        )
      end

      context 'when the error has a different error type' do
        let(:graphql_result) do
          { 'errors' => [{ 'message' => 'Search throttled', 'extensions' => { 'error_type' => 'other' } }] }
        end

        it 'returns a generic error' do
          expect(tool.execute).to include(
            isError: true,
            content: [{ type: 'text', text: 'Search throttled' }],
            structuredContent: {}
          )
        end
      end
    end

    context 'when mutation returns business logic errors' do
      let(:graphql_result) do
        {
          'data' => {
            'testMutation' => {
              'result' => nil,
              'errors' => ['Title cannot be blank']
            }
          }
        }
      end

      let(:error_response) { instance_double(Mcp::Tools::Base::Response) }

      before do
        allow(::Mcp::Tools::Base::Response).to receive(:error).and_return(error_response)
      end

      it 'returns error response with mutation errors' do
        result = tool.execute

        expect(::Mcp::Tools::Base::Response).to have_received(:error).with('Title cannot be blank',
          reason: :bad_request)
        expect(result).to eq(error_response)
      end
    end

    context 'when mutation returns multiple errors' do
      let(:graphql_result) do
        {
          'data' => {
            'testMutation' => {
              'result' => nil,
              'errors' => ['Title cannot be blank', 'Description is too short']
            }
          }
        }
      end

      let(:error_response) { instance_double(Mcp::Tools::Base::Response) }

      before do
        allow(::Mcp::Tools::Base::Response).to receive(:error).and_return(error_response)
      end

      it 'returns error response with joined errors' do
        result = tool.execute

        expect(::Mcp::Tools::Base::Response).to have_received(:error)
          .with('Title cannot be blank, Description is too short', reason: :bad_request)
        expect(result).to eq(error_response)
      end
    end

    context 'when GraphQL returns errors with non-standard format' do
      let(:graphql_result) do
        {
          'errors' => [
            123 # Non-string, non-hash error
          ]
        }
      end

      let(:error_response) { instance_double(Mcp::Tools::Base::Response) }

      before do
        allow(::Mcp::Tools::Base::Response).to receive(:error).and_return(error_response)
      end

      it 'converts non-standard errors to strings' do
        result = tool.execute

        expect(::Mcp::Tools::Base::Response).to have_received(:error).with('123')
        expect(result).to eq(error_response)
      end
    end

    context 'when operation returns no data' do
      let(:graphql_result) do
        {
          'data' => {
            'otherOperation' => {}
          }
        }
      end

      let(:error_response) { instance_double(Mcp::Tools::Base::Response) }

      before do
        allow(::Mcp::Tools::Base::Response).to receive(:error).and_return(error_response)
      end

      it 'returns error response' do
        result = tool.execute

        expect(::Mcp::Tools::Base::Response).to have_received(:error).with('Operation returned no data',
          reason: :not_found)
        expect(result).to eq(error_response)
      end

      context 'when a result-aware hook does not handle missing data' do
        before do
          allow(tool).to receive(:resource_not_found_error_for_result).and_return(nil)
        end

        it 'falls back to the default not-found error' do
          expect(tool.execute).to eq(error_response)
          expect(::Mcp::Tools::Base::Response).to have_received(:error).with('Operation returned no data',
            reason: :not_found)
        end
      end
    end

    context 'with different versions' do
      let(:tool_v1) { test_tool_class.new(current_user: user, params: params, version: '1.0.0', access_token: nil) }
      let(:tool_v2) { test_tool_class.new(current_user: user, params: params, version: '2.0.0', access_token: nil) }

      let(:graphql_result_v1) do
        {
          'data' => {
            'testMutation' => {
              'result' => { 'id' => 'gid://gitlab/Test/1' },
              'errors' => []
            }
          }
        }
      end

      it 'uses version-specific GraphQL operations' do
        allow(GitlabSchema).to receive(:execute).and_return(graphql_result_v1)

        tool_v1.execute

        expect(GitlabSchema).to have_received(:execute) do |operation, **_options|
          expect(operation).to include('result { id }')
          expect(operation).not_to include('title')
        end
      end

      it 'uses version-specific variable building' do
        params_v2 = { project_path: 'gitlab-org/gitlab', include_archived: true }
        tool_v2_with_params = test_tool_class.new(
          current_user: user,
          params: params_v2,
          version: '2.0.0',
          access_token: nil
        )

        allow(GitlabSchema).to receive(:execute).and_return(graphql_result)

        tool_v2_with_params.execute

        expect(GitlabSchema).to have_received(:execute).with(
          anything,
          variables: {
            input: {
              projectPath: 'gitlab-org/gitlab',
              includeArchived: true
            }
          },
          context: anything
        )
      end
    end
  end

  describe '#execute with an inferred operation_name' do
    before do
      allow(::Mcp::Tools::Base::Response).to receive(:error).and_call_original
      allow(::Mcp::Tools::Base::Response).to receive(:success).and_call_original
    end

    context 'when the response has a single root field' do
      let(:graphql_result) { { 'data' => { 'project' => { 'id' => 'gid://gitlab/Project/1' } } } }

      before do
        allow(GitlabSchema).to receive(:execute).and_return(graphql_result)
      end

      it 'returns a success response with the root field payload' do
        result = inferred_tool.execute

        expect(result).to include(isError: false)
        expect(result[:structuredContent]).to eq({ 'id' => 'gid://gitlab/Project/1' })
      end
    end

    context 'when data is empty' do
      let(:graphql_result) { { 'data' => {} } }

      before do
        allow(GitlabSchema).to receive(:execute).and_return(graphql_result)
      end

      it 'returns a not-found error' do
        expect(inferred_tool.execute).to include(
          isError: true,
          reason: :not_found,
          content: [{ type: 'text', text: 'Operation returned no data' }]
        )
      end
    end

    context 'when the inferred payload has errors' do
      let(:graphql_result) { { 'data' => { 'project' => { 'errors' => ['Not allowed'] } } } }

      before do
        allow(GitlabSchema).to receive(:execute).and_return(graphql_result)
      end

      it 'returns a bad request error' do
        expect(inferred_tool.execute).to include(
          isError: true,
          reason: :bad_request,
          content: [{ type: 'text', text: 'Not allowed' }]
        )
      end
    end

    context 'when the granular token is denied during execution' do
      let(:access_token) { build_stubbed(:personal_access_token, user: user) }
      let(:inferred_tool) { inferred_tool_class.new(current_user: user, params: params, access_token: access_token) }

      [
        { 'data' => { 'project' => nil } },
        { 'data' => {} }
      ].each do |denied_result|
        context "when the result is #{denied_result}" do
          before do
            allow(GitlabSchema).to receive(:execute) do
              ::Current.add_granular_denied_permissions([:read_project])
              denied_result
            end
          end

          it 'returns an access denied error' do
            expect(inferred_tool.execute).to include(isError: true, reason: :unauthorized)
          end
        end
      end
    end

    context 'when the response has multiple root fields and no explicit operation_name' do
      let(:graphql_result) { { 'data' => { 'project' => { 'id' => 1 }, 'group' => { 'id' => 2 } } } }

      before do
        allow(GitlabSchema).to receive(:execute).and_return(graphql_result)
      end

      it 'raises MultipleRootFieldsError' do
        expect { inferred_tool.execute }.to raise_error(Mcp::Tools::Base::GraphqlTool::MultipleRootFieldsError)
      end

      context 'when permissions were denied earlier in the request' do
        before do
          ::Current.add_granular_denied_permissions(%i[read_project read_code])
        end

        it 'keeps the earlier denials recorded even though execute raises' do
          expect { inferred_tool.execute }.to raise_error(Mcp::Tools::Base::GraphqlTool::MultipleRootFieldsError)

          expect(::Current.granular_denied_permissions).to contain_exactly(:read_project, :read_code)
        end
      end
    end
  end

  describe 'versioning integration' do
    it 'supports multiple versions with different operations' do
      tool_v1 = test_tool_class.new(current_user: user, params: params, version: '1.0.0', access_token: nil)
      tool_v2 = test_tool_class.new(current_user: user, params: params, version: '2.0.0', access_token: nil)

      operation_v1 = tool_v1.graphql_operation
      operation_v2 = tool_v2.graphql_operation

      expect(operation_v1).to include('result { id }')
      expect(operation_v1).not_to include('title')

      expect(operation_v2).to include('result { id title description }')
    end

    it 'uses latest version by default' do
      default_tool = test_tool_class.new(current_user: user, params: params, access_token: nil)

      expect(default_tool.version).to eq('2.0.0')
      expect(default_tool.graphql_operation).to include('result { id title description }')
    end
  end
end
