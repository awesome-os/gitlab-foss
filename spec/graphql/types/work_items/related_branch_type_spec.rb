# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::WorkItems::RelatedBranchType, feature_category: :team_planning do
  include GraphqlHelpers

  it { expect(described_class.graphql_name).to eq('WorkItemRelatedBranch') }

  it { expect(described_class).to have_graphql_fields(:name, :compare_path, :pipeline_status) }

  describe 'pipeline_status' do
    let_it_be(:project) { create(:project, :public, public_builds: false) }
    let_it_be(:developer) { create(:user, developer_of: project) }
    let_it_be(:pipeline) { create(:ci_pipeline, :success, project: project) }

    let(:branch) do
      Types::WorkItems::Widgets::DevelopmentType::RelatedBranch.new(
        name: pipeline.ref, compare_path: nil, target: pipeline.sha, project: project
      )
    end

    it 'has a field-level granular scope directive requiring read_pipeline on the project boundary' do
      directive = described_class.fields['pipelineStatus'].directives
        .find { |d| d.is_a?(Directives::Authz::GranularScope) }
      expect(directive).not_to be_nil

      args = directive.arguments.keyword_arguments
      expect(args[:permissions]).to eq(['read_pipeline'])
      expect(args[:boundary_type]).to eq('project')
      expect(args[:boundary]).to eq('project')
    end

    it 'builds the status of the latest pipeline for the user the field is resolved for', :aggregate_failures do
      status = resolve_field(:pipeline_status, branch, current_user: developer)

      expect(status.subject).to eq(pipeline)
      expect(status.user).to eq(developer)
      expect(status.label).to eq('passed')
    end

    it 'returns no status to a user who cannot read the pipeline' do
      expect(resolve_field(:pipeline_status, branch, current_user: nil)).to be_nil
    end

    it 'returns no status when the branch points to a commit without a pipeline' do
      branch.target = '1' * 40

      expect(resolve_field(:pipeline_status, branch, current_user: developer)).to be_nil
    end

    it 'returns no status for a branch without a pipeline' do
      branch.name = 'branch-without-pipeline'

      expect(resolve_field(:pipeline_status, branch, current_user: developer)).to be_nil
    end
  end
end
