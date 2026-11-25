# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mcp::Tools::Jobs::SavePipelineJobTool, feature_category: :mcp_server do
  using RSpec::Parameterized::TableSyntax

  let_it_be(:user) { create(:user) }
  let_it_be(:access_token) { create(:personal_access_token, user: user, scopes: [:mcp]) }
  let_it_be(:project) do
    create(:project, :public, maintainers: [user], ci_pipeline_variables_minimum_override_role: :maintainer)
  end

  let_it_be(:pipeline) { create(:ci_pipeline, project: project) }

  let(:job) { create(:ci_build, :playable, pipeline: pipeline) }
  let(:params) { { project_id: project.full_path, job_id: job.id } }
  let(:tool) { described_class.new(current_user: user, params: params, access_token: access_token) }

  describe '#build_variables' do
    it 'uses the loaded job global ID' do
      expect(tool.build_variables).to eq(input: { id: job.to_global_id.to_s })
    end

    context 'with a job URL' do
      let(:url) { Gitlab::Routing.url_helpers.project_job_url(project, job) }
      let(:params) { { url: url } }

      it 'uses the job identified by the URL' do
        expect(tool.build_variables).to eq(input: { id: job.to_global_id.to_s })
      end

      context 'with query parameters and a fragment' do
        let(:url) { "#{super()}?foo=bar#L10" }

        it 'uses the job URL path' do
          expect(tool.build_variables).to eq(input: { id: job.to_global_id.to_s })
        end
      end

      context 'with a relative URL root' do
        let(:url) { "https://gitlab.example.com:3443/gitlab/#{project.full_path}/-/jobs/#{job.id}" }

        before do
          stub_config_setting(relative_url_root: '/gitlab')
          described_class.clear_memoization(:relative_url_root_regex)
        end

        after do
          described_class.clear_memoization(:relative_url_root_regex)
        end

        it 'strips the root before resolving the project' do
          expect(tool.build_variables).to eq(input: { id: job.to_global_id.to_s })
        end
      end

      context 'with matching identifiers' do
        where(:project_identifier, :include_job_id) do
          :path    | false
          :numeric | false
          nil      | true
          :path    | true
          :numeric | true
        end

        with_them do
          let(:params) do
            identifiers = {}

            if project_identifier
              identifiers[:project_id] = project_identifier == :numeric ? project.id.to_s : project.full_path
            end

            identifiers[:job_id] = job.id if include_job_id

            super().merge(identifiers)
          end

          it 'accepts identifiers for the same project and job' do
            expect(tool.build_variables).to eq(input: { id: job.to_global_id.to_s })
          end
        end
      end

      context 'with a conflicting project ID' do
        let_it_be(:other_project) { create(:project, :public) }
        let(:params) { super().merge(project_id: other_project.full_path) }

        it 'rejects the conflicting project' do
          expect { tool.build_variables }.to raise_error(ArgumentError, 'project_id does not match the job URL')
        end
      end

      context 'with a conflicting job ID' do
        let(:params) { super().merge(job_id: non_existing_record_id) }

        it 'rejects the conflicting job' do
          expect { tool.build_variables }.to raise_error(ArgumentError, 'job_id does not match the job URL')
        end
      end

      context 'with an invalid URL' do
        where(:url) do
          [
            'not a URL',
            'ftp://gitlab.example.com/group/project/-/jobs/1',
            'https://gitlab.example.com/group/project',
            'https://gitlab.example.com/group/project/-/pipelines/1',
            'https://gitlab.example.com/group/project/-/jobs/not-a-number',
            'https://gitlab.example.com/group/project/-/jobs/1/artifacts',
            'https://gitlab.example.com/group/project/-/jobs/1/artifacts/file/report.txt',
            'https://gitlab.example.com/group/project/-/jobs/1/artifacts/raw/report.txt'
          ]
        end

        with_them do
          it 'rejects the URL' do
            expect { tool.build_variables }.to raise_error(ArgumentError, /Invalid (job URL:|URL format)/)
          end
        end
      end
    end

    context 'with no variables to pass' do
      where(variables: [nil, []])

      with_them do
        let(:params) { super().merge(variables: variables) }

        it 'omits the variables input' do
          expect(tool.build_variables).to eq(input: { id: job.to_global_id.to_s })
        end
      end
    end

    context 'with variables using string and symbol keys' do
      let(:params) do
        super().merge(variables: [
          { 'key' => 'DEPLOY_ENV', 'value' => 'staging', 'variable_type' => 'env_var' },
          { key: 'CONFIG', value: 'configuration', variable_type: 'file' },
          { key: 'DEFAULT_TYPE', value: 'default' }
        ])
      end

      it 'maps the field names and enum values without inventing a missing type' do
        expect(tool.build_variables).to eq(
          input: {
            id: job.to_global_id.to_s,
            variables: [
              { key: 'DEPLOY_ENV', value: 'staging', variableType: 'ENV_VAR' },
              { key: 'CONFIG', value: 'configuration', variableType: 'FILE' },
              { key: 'DEFAULT_TYPE', value: 'default' }
            ]
          }
        )
      end
    end
  end

  describe '#execute' do
    before do
      allow(GitlabSchema).to receive(:execute).and_return(graphql_result)
    end

    context 'when GraphQL reports an authorization failure among other errors #security' do
      let(:access_error) { Gitlab::Graphql::Authorize::AuthorizeResource::RESOURCE_ACCESS_ERROR }
      let(:graphql_result) do
        { 'errors' => ['Operation failed', { 'message' => access_error }, { 'message' => 'Private job details' }] }
      end

      it 'returns only the vague access error without exposing unrelated errors', :aggregate_failures do
        result = tool.execute

        expect(result[:isError]).to be(true)
        expect(Mcp::Tools::Base::Response.error_reason(result)).to eq(:unauthorized)
        expect(result[:content].first[:text]).to eq(access_error)
      end
    end

    context 'when GraphQL returns job details' do
      let(:job_path) { "/gitlab/custom/jobs/#{job.id}" }
      let(:pipeline_path) { "/gitlab/custom/pipelines/#{pipeline.id}" }
      let(:graphql_result) do
        {
          'data' => {
            'jobPlay' => {
              'job' => {
                'id' => job.to_global_id.to_s,
                'name' => job.name,
                'status' => 'PENDING',
                'stage' => { 'name' => job.stage },
                'pipeline' => { 'id' => pipeline.to_global_id.to_s, 'path' => pipeline_path },
                'webPath' => job_path
              },
              'errors' => []
            }
          }
        }
      end

      before do
        allow(Gitlab.config.gitlab).to receive(:url).and_return('https://gitlab.example.com:3443/gitlab')
      end

      it 'uses the returned paths and preserves the host, port, and relative URL root', :aggregate_failures do
        result = tool.execute

        expect(result[:isError]).to be(false)
        expect(result[:structuredContent]).to include(
          web_url: "https://gitlab.example.com:3443#{job_path}",
          pipeline_web_url: "https://gitlab.example.com:3443#{pipeline_path}"
        )
      end

      context 'when the returned paths are null' do
        let(:job_path) { nil }
        let(:pipeline_path) { nil }

        it 'returns null URLs', :aggregate_failures do
          result = tool.execute

          expect(result[:isError]).to be(false)
          expect(result[:structuredContent]).to include(web_url: nil, pipeline_web_url: nil)
        end
      end

      context 'when nullable job fields are null' do
        let(:graphql_result) do
          super().deep_merge('data' => {
            'jobPlay' => {
              'job' => { 'id' => nil, 'status' => nil, 'stage' => nil, 'pipeline' => nil, 'webPath' => nil }
            }
          })
        end

        it 'formats the nullable fields without raising', :aggregate_failures do
          result = tool.execute

          expect(result[:isError]).to be(false)
          expect(result[:structuredContent]).to include(
            id: 0, status: nil, stage: nil, pipeline_id: 0, web_url: nil, pipeline_web_url: nil
          )
        end
      end
    end

    context 'when GraphQL returns an unsuccessful response' do
      where(:graphql_result, :message, :reason) do
        { 'errors' => [{ 'message' => 'Execution failed' }] } |
          'Execution failed' | :error
        { 'data' => { 'jobPlay' => nil } } |
          'Operation returned no data' | :not_found
        { 'data' => { 'jobPlay' => { 'job' => nil, 'errors' => ['Job could not be played'] } } } |
          'Job could not be played' | :bad_request
        { 'data' => { 'jobPlay' => { 'job' => nil, 'errors' => [] } } } |
          'Operation returned no job data' | :error
      end

      with_them do
        it 'preserves the error instead of formatting a job', :aggregate_failures do
          result = tool.execute

          expect(result[:isError]).to be(true)
          expect(result[:content].first[:text]).to eq(message)
          expect(Mcp::Tools::Base::Response.error_reason(result)).to eq(reason)
        end
      end
    end
  end
end
