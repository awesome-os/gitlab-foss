# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Pipeline inputs (JavaScript fixtures)', type: :request, feature_category: :pipeline_composition do
  include GraphqlHelpers
  include JavaScriptFixturesHelpers
  include ReactiveCachingHelpers

  let_it_be(:namespace) { create(:namespace, name: 'frontend-fixtures') }
  let_it_be(:project) { create(:project, :small_repo, namespace: namespace, path: 'pipeline-inputs-project') }
  let_it_be(:user) { create(:user, developer_of: project) }

  let_it_be(:query) do
    get_graphql_query_as_string('ci/common/pipeline_inputs/graphql/queries/pipeline_creation_inputs.query.graphql')
  end

  configs = {
    'basic' => <<~YAML,
      spec:
        inputs:
          deploy_environment:
            description: 'Specify deployment environment'
            options: ['staging', 'production']
            default: 'staging'
            regex: '^(staging|production)$'
          api_token:
            description: 'API token for deployment'
          tags:
            description: 'Tags for deployment'
            type: array
            default: []
    YAML
    'rules' => <<~YAML,
      spec:
        inputs:
          cloud_provider:
            description: 'Cloud provider selection'
            options: ['aws', 'gcp', 'azure', 'custom']
            default: 'aws'
          environment:
            description: 'Environment selection'
            options: ['dev', 'prod']
            default: 'dev'
          instance_type:
            description: 'Instance type selection'
            rules:
              - if: $[[ inputs.cloud_provider ]] == 'aws' && $[[ inputs.environment ]] == 'dev'
                options: ['t3.micro', 't3.small']
                default: 't3.micro'
              - if: $[[ inputs.cloud_provider ]] == 'aws' && $[[ inputs.environment ]] == 'prod'
                options: ['m5.large', 'm5.xlarge']
                default: 'm5.large'
              - if: $[[ inputs.cloud_provider ]] == 'gcp'
                options: ['e2-small', 'e2-medium']
                default: 'e2-small'
              - if: $[[ inputs.cloud_provider ]] == 'custom'
                default: ''
    YAML
    'complex_rules' => <<~YAML,
      spec:
        inputs:
          cloud_provider:
            description: 'Cloud provider selection'
            options: ['aws', 'gcp', 'azure', 'custom']
            default: 'aws'
          environment:
            description: 'Environment selection'
            options: ['dev', 'prod']
            default: 'dev'
          special_feature:
            description: 'Special feature that depends on complex conditions'
            rules:
              - if: ($[[ inputs.cloud_provider ]] == 'aws' && $[[ inputs.environment ]] == 'prod') || $[[ inputs.cloud_provider ]] == 'azure'
                options: ['premium-feature', 'enterprise-feature']
                default: 'premium-feature'
    YAML
    'chained_rules' => <<~YAML,
      spec:
        inputs:
          environment:
            options: ['development', 'production']
            default: 'development'
          instance_type:
            description: 'VM instance size'
            rules:
              - if: $[[ inputs.environment ]] == 'development'
                options: ['small', 'medium']
                default: 'small'
              - if: $[[ inputs.environment ]] == 'production'
                options: ['large', 'xlarge']
                default: 'large'
          extra_config:
            description: 'Extra config that depends on instance_type'
            rules:
              - if: $[[ inputs.instance_type ]] == 'small'
                options: ['opt1', 'opt2']
                default: 'opt1'
              - if: $[[ inputs.instance_type ]] == 'large'
                options: ['opt3', 'opt4']
                default: 'opt3'
    YAML
    'array_rules' => <<~YAML
      spec:
        inputs:
          environment:
            options: ['development', 'production']
            default: 'development'
          instance_type:
            description: 'VM instance size'
            type: array
            rules:
              - if: $[[ inputs.environment ]] == 'development'
                options: ['small', 'medium']
                default: ['small']
              - if: $[[ inputs.environment ]] == 'production'
                options: ['large', 'xlarge']
                default: ['large']
    YAML
  }

  before_all do
    configs.each do |name, spec|
      project.repository.create_file(
        user,
        '.gitlab-ci.yml',
        "#{spec}---\njob:\n  script: echo\n",
        message: "Add #{name} inputs",
        branch_name: name
      )
    end

    project.repository.create_file(
      user,
      '.gitlab-ci.yml',
      "job:\n  script: echo\n",
      message: 'Add CI without inputs',
      branch_name: 'empty'
    )
  end

  def post_inputs_query(ref)
    service = Ci::PipelineCreation::FindPipelineInputsService.new(current_user: user, project: project, ref: ref)
    allow(Ci::PipelineCreation::FindPipelineInputsService).to receive(:new).and_return(service)
    synchronous_reactive_cache(service)

    post_graphql(query, current_user: user, variables: { fullPath: project.full_path, ref: ref })
  end

  [*configs.keys, 'empty'].each do |name|
    it "graphql/ci/common/pipeline_inputs/pipeline_creation_inputs.query.graphql.#{name}.json" do
      post_inputs_query(name)

      expect_graphql_errors_to_be_empty
    end
  end

  it 'graphql/ci/common/pipeline_inputs/pipeline_creation_inputs.query.graphql.error.json' do
    post_inputs_query('missing-ref')

    expect(graphql_errors).to be_present
  end
end
