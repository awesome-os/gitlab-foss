# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mcp::Tools::Jobs::SavePipelineJobService, feature_category: :mcp_server do
  using RSpec::Parameterized::TableSyntax

  let_it_be(:user) { create(:user) }
  let_it_be_with_reload(:project) do
    create(:project, :public, :small_repo, developers: [user],
      ci_pipeline_variables_minimum_override_role: :developer)
  end

  let_it_be(:pipeline) { create(:ci_pipeline, project: project, user: user, sha: project.commit.sha) }

  let(:deploy_stage) { create(:ci_stage, pipeline: pipeline, name: 'deploy') }
  let(:job) { create(:ci_build, :playable, pipeline: pipeline, name: 'deploy_staging', ci_stage: deploy_stage) }
  let(:current_user) { user }
  let(:access_token) { create(:personal_access_token, user: current_user, scopes: [:mcp]) }
  let(:service) { described_class.new(name: 'save_pipeline_job') }
  let(:arguments) { { project_id: project.full_path, job_id: job.id } }

  subject(:execute_service) { service.execute(params: { arguments: arguments }) }

  before do
    service.set_cred(current_user: current_user, access_token: access_token)
  end

  describe '#input_schema' do
    it 'locks the input contract for version 0.1.0' do
      expect(service.input_schema).to eq(
        type: 'object',
        additionalProperties: false,
        required: [],
        properties: {
          url: {
            type: 'string',
            description: 'Full URL of the manual job to play'
          },
          project_id: {
            type: 'string',
            description: 'ID or full path of the project, for example gitlab-org/gitlab'
          },
          job_id: {
            type: 'integer',
            description: 'ID of the manual job to play'
          },
          variables: {
            type: 'array',
            description: 'CI/CD variables to pass to the manual job.',
            items: {
              type: 'object',
              properties: {
                key: { type: 'string', description: 'Name of the variable.' },
                value: { type: 'string', description: 'Value of the variable' },
                variable_type: {
                  type: 'string',
                  enum: %w[env_var file],
                  description: 'Type of the variable.'
                }
              },
              required: %w[key value]
            }
          }
        }
      )
    end
  end

  describe '#execute' do
    it 'plays the existing job and returns its details', :aggregate_failures do
      job

      expect { execute_service }.not_to change { pipeline.builds.count }

      expect(execute_service[:isError]).to be(false)
      expect(job.reload).to be_pending
      expect(execute_service[:structuredContent]).to eq(
        id: job.id,
        name: 'deploy_staging',
        status: 'pending',
        stage: 'deploy',
        pipeline_id: pipeline.id,
        web_url: Gitlab::Routing.url_helpers.project_job_url(project, job),
        pipeline_web_url: Gitlab::Routing.url_helpers.project_pipeline_url(project, pipeline)
      )
      expect(Gitlab::Json::SafeParser.parse(execute_service[:content].first[:text]))
        .to eq(execute_service[:structuredContent].deep_stringify_keys)
    end

    context 'with a numeric project ID' do
      let(:arguments) { { project_id: project.id.to_s, job_id: job.id } }

      it 'plays the job', :aggregate_failures do
        expect(execute_service[:isError]).to be(false)
        expect(job.reload).to be_pending
      end
    end

    context 'with a job URL' do
      let(:arguments) { { url: Gitlab::Routing.url_helpers.project_job_url(project, job) } }

      it 'plays the job identified by the URL', :aggregate_failures do
        expect(execute_service[:isError]).to be(false)
        expect(execute_service[:structuredContent]).to include(id: job.id)
        expect(job.reload).to be_pending
      end

      context 'with conflicting identifiers' do
        where(:identifier) { %i[project_id job_id] }

        with_them do
          let(:other_project) { create(:project, :public) }
          let(:arguments) do
            value = identifier == :project_id ? other_project.full_path : non_existing_record_id
            super().merge(identifier => value)
          end

          it 'rejects the call without playing the job', :aggregate_failures do
            expect(GitlabSchema).not_to receive(:execute)

            expect(Mcp::Tools::Base::Response.error_reason(execute_service)).to eq(:bad_request)
            expect(execute_service[:content].first[:text]).to include("#{identifier} does not match the job URL")
            expect(job.reload).to be_manual
          end
        end
      end

      context 'when the URL points to a job in another project' do
        let_it_be(:other_project) { create(:project, :public, developers: [user]) }
        let(:arguments) { { url: Gitlab::Routing.url_helpers.project_job_url(other_project, job) } }

        it 'returns not found without playing the job #security', :aggregate_failures do
          expect(GitlabSchema).not_to receive(:execute)

          expect(Mcp::Tools::Base::Response.error_reason(execute_service)).to eq(:not_found)
          expect(job.reload).to be_manual
        end
      end
    end

    context 'with variables' do
      let(:arguments) do
        super().merge(variables: [
          { key: 'DEPLOY_ENV', value: 'staging' },
          { key: 'CONFIG', value: 'configuration', variable_type: 'file' }
        ])
      end

      it 'persists the variables on the played job', :aggregate_failures do
        expect(execute_service[:isError]).to be(false)
        expect(job.reload).to be_pending
        expect(job.job_variables.map { |variable| [variable.key, variable.value, variable.variable_type] })
          .to contain_exactly(%w[DEPLOY_ENV staging env_var], %w[CONFIG configuration file])
      end

      context 'when the developer cannot override variables' do
        before do
          project.update!(ci_pipeline_variables_minimum_override_role: :maintainer)
        end

        it 'explains the variable permission denial and leaves the job unchanged #security', :aggregate_failures do
          expect(GitlabSchema).not_to receive(:execute)

          expect(Mcp::Tools::Base::Response.error_reason(execute_service)).to eq(:unauthorized)
          expect(execute_service[:isError]).to be(true)
          expect(execute_service[:content].first[:text])
            .to include('You do not have permission to pass variables to this job')
          expect(job.reload).to be_manual
          expect(job.job_variables).to be_empty
        end

        context 'when no variables are passed' do
          where(variables: [nil, []])

          with_them do
            let(:arguments) { super().merge(variables: variables) }

            it 'plays the job without variables', :aggregate_failures do
              expect(execute_service[:isError]).to be(false)
              expect(job.reload).to be_pending
              expect(job.job_variables).to be_empty
            end
          end
        end
      end
    end

    context 'when the job is not manual' do
      where(trait: %i[success failed canceled running scheduled])

      with_them do
        let(:job) { create(:ci_build, :playable, trait, pipeline: pipeline) }

        it 'rejects the job before executing GraphQL instead of retrying it', :aggregate_failures do
          original_status = job.status
          expect(GitlabSchema).not_to receive(:execute)

          expect { execute_service }.not_to change { pipeline.builds.count }

          expect(execute_service[:isError]).to be(true)
          expect(Mcp::Tools::Base::Response.error_reason(execute_service)).to eq(:bad_request)
          expect(execute_service[:content].first[:text]).to include('Job must be a playable manual job')
          expect(job.reload.status).to eq(original_status)
        end
      end
    end

    context 'when the manual job is no longer playable' do
      let(:job) { create(:ci_build, :manual, pipeline: pipeline, when: 'on_success') }

      it 'rejects it before executing GraphQL', :aggregate_failures do
        expect(GitlabSchema).not_to receive(:execute)

        expect(Mcp::Tools::Base::Response.error_reason(execute_service)).to eq(:bad_request)
        expect(job.reload).to be_manual
      end
    end

    context 'when the manual job is archived' do
      let(:job) { create(:ci_build, :playable, :degenerated, pipeline: pipeline) }

      it 'returns unauthorized without exposing its state #security', :aggregate_failures do
        expect(GitlabSchema).not_to receive(:execute)

        expect(Mcp::Tools::Base::Response.error_reason(execute_service)).to eq(:unauthorized)
        expect(execute_service[:content].first[:text]).to include('Job not found or inaccessible')
        expect(job.reload).to be_manual
      end
    end

    context 'when the job belongs to another project' do
      let_it_be(:other_project) { create(:project, :public, developers: [user]) }
      let(:arguments) { { project_id: other_project.full_path, job_id: job.id } }

      it 'returns not found without playing the job #security', :aggregate_failures do
        expect(GitlabSchema).not_to receive(:execute)

        expect(Mcp::Tools::Base::Response.error_reason(execute_service)).to eq(:not_found)
        expect(execute_service[:content].first[:text]).to include('Job not found or inaccessible')
        expect(job.reload).to be_manual
      end
    end

    context 'when the job does not exist' do
      let(:arguments) { { project_id: project.full_path, job_id: non_existing_record_id } }

      it 'returns not found' do
        expect(Mcp::Tools::Base::Response.error_reason(execute_service)).to eq(:not_found)
      end
    end

    context 'when the project does not exist' do
      let(:arguments) { { project_id: non_existing_record_id.to_s, job_id: job.id } }

      it 'returns not found' do
        expect(Mcp::Tools::Base::Response.error_reason(execute_service)).to eq(:not_found)
      end
    end

    context 'when the user cannot access the project' do
      let_it_be(:private_project) { create(:project, :private) }
      let(:arguments) { { project_id: private_project.full_path, job_id: job.id } }

      it 'returns a vague unauthorized error #security', :aggregate_failures do
        expect(Mcp::Tools::Base::Response.error_reason(execute_service)).to eq(:unauthorized)
        expect(execute_service[:content].first[:text]).to include('not found or inaccessible')
        expect(job.reload).to be_manual
      end
    end

    context 'when the user can read the job but cannot play it' do
      let_it_be(:reporter) { create(:user, reporter_of: project) }
      let(:current_user) { reporter }

      it 'refuses the job before executing GraphQL #security', :aggregate_failures do
        expect(GitlabSchema).not_to receive(:execute)

        expect(Mcp::Tools::Base::Response.error_reason(execute_service)).to eq(:unauthorized)
        expect(execute_service[:content].first[:text]).to include('Job not found or inaccessible')
        expect(job.reload).to be_manual
      end
    end

    context 'when CI/CD visibility is restricted to project members' do
      let_it_be(:outsider) { create(:user) }
      let(:current_user) { outsider }

      before do
        project.update!(public_builds: false)
      end

      where(status: %w[manual success failed])

      with_them do
        let(:job) { create(:ci_build, :playable, pipeline: pipeline, status: status) }

        it 'does not reveal whether the job exists or its state #security', :aggregate_failures do
          expect(GitlabSchema).not_to receive(:execute)

          missing_job = service.execute(params: {
            arguments: { project_id: project.full_path, job_id: non_existing_record_id }
          })

          expect(Mcp::Tools::Base::Response.error_reason(execute_service)).to eq(:unauthorized)
          expect(execute_service[:content]).to eq(missing_job[:content])
          expect(job.reload.status).to eq(status)
        end
      end
    end

    context 'with a granular token' do
      let(:token_boundary) { ::Authz::Boundary.for(:user) }
      let(:token_permissions) { [:execute_mcp_tool] }
      let(:access_token) do
        create(:granular_pat, user: user, boundary: token_boundary, permissions: token_permissions)
      end

      context 'without project permissions' do
        where(status: %w[manual success])

        with_them do
          let(:job) { create(:ci_build, :playable, pipeline: pipeline, status: status) }

          it 'refuses existing and missing jobs without exposing their state #security', :aggregate_failures do
            expect(GitlabSchema).not_to receive(:execute)

            missing_job = service.execute(params: {
              arguments: { project_id: project.full_path, job_id: non_existing_record_id }
            })

            expect(Mcp::Tools::Base::Response.error_reason(execute_service)).to eq(:unauthorized)
            expect(execute_service[:content]).to eq(missing_job[:content])
            expect(execute_service[:content].first[:text]).to include('Access denied: This operation requires')
            expect(job.reload.status).to eq(status)
          end
        end
      end

      context 'with the run_job project permission' do
        let(:token_boundary) { ::Authz::Boundary.for(project) }
        let(:token_permissions) { [:run_job] }

        before do
          project.update!(visibility_level: Gitlab::VisibilityLevel::PRIVATE)
        end

        it 'reports success when the token cannot read the played job #security', :aggregate_failures do
          expect { execute_service }.to change { job.reload.status }.from('manual').to('pending')

          expect(execute_service[:isError]).to be(false)
          expect(execute_service[:content].first[:text]).to include(
            'Operation completed successfully.',
            'The token needs these permissions to read the result:',
            'Job: Read'
          )
          expect(execute_service[:content].first[:text]).not_to include('Do not repeat', 'Access denied')
          expect(execute_service[:structuredContent]).to be_empty
        end

        context 'with the response read permissions' do
          let(:token_permissions) { %i[run_job read_job read_pipeline] }

          it 'plays the job and returns its details', :aggregate_failures do
            expect(execute_service[:isError]).to be(false)
            expect(execute_service[:structuredContent]).to include(
              id: job.id, pipeline_id: pipeline.id, stage: job.stage
            )
            expect(job.reload).to be_pending
          end
        end
      end
    end

    context 'without an access token' do
      let(:access_token) { nil }

      it 'refuses the call before executing GraphQL #security', :aggregate_failures do
        expect(GitlabSchema).not_to receive(:execute)

        expect(Mcp::Tools::Base::Response.error_reason(execute_service)).to eq(:unauthorized)
        expect(execute_service[:content].first[:text]).to include('Job not found or inaccessible')
        expect(job.reload).to be_manual
      end
    end

    context 'without a current user' do
      let(:current_user) { nil }
      let(:access_token) { nil }

      it 'returns unauthorized' do
        expect(Mcp::Tools::Base::Response.error_reason(execute_service)).to eq(:unauthorized)
      end
    end

    context 'with invalid arguments' do
      where(:invalid_arguments) do
        [
          {},
          { project_id: 'example/project' },
          { job_id: 1 },
          { url: 'https://gitlab.example.com/example/project/-/pipelines/1' },
          { url: 'not a valid URL' },
          { url: 123 },
          { project_id: 'example/project', job_id: '123' },
          { project_id: 'example/project', job_id: 1, unknown: true },
          { project_id: 'example/project', job_id: 1, variables: [{ key: 'NAME' }] },
          { project_id: 'example/project', job_id: 1,
            variables: [{ key: 'NAME', value: 'value', variable_type: 'invalid' }] }
        ]
      end

      with_them do
        let(:arguments) { invalid_arguments }

        it 'rejects them before executing GraphQL', :aggregate_failures do
          expect(GitlabSchema).not_to receive(:execute)

          expect(execute_service[:isError]).to be(true)
          expect(Mcp::Tools::Base::Response.error_reason(execute_service)).to eq(:bad_request)
        end
      end
    end
  end

  describe '#governed_containers' do
    it 'governs a job URL by its project' do
      arguments = { url: Gitlab::Routing.url_helpers.project_job_url(project, job) }.with_indifferent_access

      expect(service.governed_containers(arguments).containers).to eq([project])
    end
  end
end
