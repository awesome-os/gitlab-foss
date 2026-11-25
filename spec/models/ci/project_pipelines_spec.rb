# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ci::ProjectPipelines, feature_category: :continuous_integration do
  let_it_be_with_refind(:project) { create(:project) }

  let_it_be(:web_pipeline) { create(:ci_pipeline, project: project, source: :web) }
  let_it_be(:external_pipeline) { create(:ci_pipeline, project: project, source: :external) }
  let_it_be(:webide_pipeline) { create(:ci_pipeline, project: project, source: :webide) }

  subject(:project_pipelines) { described_class.new(project) }

  shared_context 'when builds are disabled' do
    before do
      project.project_feature.update_attribute(:builds_access_level, ProjectFeature::DISABLED)
    end
  end

  describe '#all_pipelines' do
    it 'returns all pipelines' do
      expect(project_pipelines.all_pipelines).to contain_exactly(web_pipeline, external_pipeline, webide_pipeline)
    end

    context 'when builds are disabled' do
      include_context 'when builds are disabled'

      it 'returns only external pipelines' do
        expect(project_pipelines.all_pipelines).to contain_exactly(external_pipeline)
      end
    end
  end

  describe '#ci_pipelines' do
    let_it_be(:feature_pipeline) { create(:ci_pipeline, project: project, ref: 'feature', sha: 'abc123') }

    it 'excludes dangling pipelines' do
      expect(project_pipelines.ci_pipelines).to contain_exactly(web_pipeline, external_pipeline, feature_pipeline)
    end

    it 'filters by ref' do
      expect(project_pipelines.ci_pipelines(ref: 'feature')).to contain_exactly(feature_pipeline)
    end

    it 'filters by sha' do
      expect(project_pipelines.ci_pipelines(sha: 'abc123')).to contain_exactly(feature_pipeline)
    end

    context 'with a tag pipeline on the same ref' do
      let!(:tag_pipeline) { create(:ci_pipeline, project: project, ref: 'feature', tag: true) }

      it 'filters by branch, excluding tags' do
        expect(project_pipelines.ci_pipelines(branch: 'feature')).to contain_exactly(feature_pipeline)
      end
    end

    it 'raises an error when both ref and branch are given' do
      expect { project_pipelines.ci_pipelines(ref: 'feature', branch: 'feature') }
        .to raise_error(ArgumentError, 'Pass either ref or branch, not both')
    end

    it 'filters by source' do
      expect(project_pipelines.ci_pipelines(source: :web)).to contain_exactly(web_pipeline)
    end

    it 'orders by id desc' do
      expect(project_pipelines.ci_pipelines(order: :id_desc))
        .to eq([feature_pipeline, external_pipeline, web_pipeline])
    end

    it 'filters by the recent partitions' do
      allow(Ci::Partition).to receive(:recent_ids).and_return([web_pipeline.partition_id.next])

      expect(project_pipelines.ci_pipelines(recent_partitions: true)).to be_empty
    end

    it 'raises an error for an unsupported order' do
      expect { project_pipelines.ci_pipelines(order: :id_asc) }
        .to raise_error(ArgumentError, 'Unsupported order: id_asc')
    end

    context 'when builds are disabled' do
      include_context 'when builds are disabled'

      it 'returns only external pipelines' do
        expect(project_pipelines.ci_pipelines).to contain_exactly(external_pipeline)
      end
    end
  end

  describe '#find' do
    it 'finds a pipeline from any source' do
      expect(project_pipelines.find(webide_pipeline.id)).to eq(webide_pipeline)
    end

    it 'raises an error for a pipeline of another project' do
      expect { project_pipelines.find(create(:ci_pipeline).id) }.to raise_error(ActiveRecord::RecordNotFound)
    end

    context 'when builds are disabled' do
      include_context 'when builds are disabled'

      it 'raises an error for a non-external pipeline' do
        expect { project_pipelines.find(web_pipeline.id) }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end

  describe '#find_by_id' do
    it 'finds a pipeline from any source' do
      expect(project_pipelines.find_by_id(webide_pipeline.id)).to eq(webide_pipeline)
    end

    it 'returns nil for a pipeline of another project' do
      expect(project_pipelines.find_by_id(create(:ci_pipeline).id)).to be_nil
    end
  end

  describe '#latest' do
    let_it_be(:feature_pipeline) { create(:ci_pipeline, project: project, ref: 'feature') }

    it 'returns the newest pipeline' do
      expect(project_pipelines.latest).to eq(feature_pipeline)
    end

    it 'returns the newest pipeline for the ref' do
      expect(project_pipelines.latest(ref: external_pipeline.ref)).to eq(external_pipeline)
    end

    context 'with a newer tag pipeline on the same ref' do
      let!(:tag_pipeline) { create(:ci_pipeline, project: project, ref: 'feature', tag: true) }

      it 'returns the newest pipeline for the branch' do
        expect(project_pipelines.latest(branch: 'feature')).to eq(feature_pipeline)
      end
    end
  end

  describe '#latest_in_default_branch' do
    let_it_be(:other_branch_pipeline) { create(:ci_pipeline, project: project, ref: 'feature') }

    before do
      allow(project).to receive(:default_branch).and_return(external_pipeline.ref)
    end

    it 'returns the newest pipeline for the default branch' do
      expect(project_pipelines.latest_in_default_branch).to eq(external_pipeline)
    end

    context 'when builds are disabled' do
      include_context 'when builds are disabled'

      let_it_be(:newer_web_pipeline) { create(:ci_pipeline, project: project, source: :web) }

      it 'returns the newest external pipeline for the default branch' do
        expect(project_pipelines.latest_in_default_branch).to eq(external_pipeline)
      end
    end
  end

  describe '#any_ci_pipelines?' do
    it { is_expected.to be_any_ci_pipelines }

    context 'when the project has only dangling pipelines' do
      let_it_be(:project) { create(:project) }
      let_it_be(:webide_pipeline) { create(:ci_pipeline, project: project, source: :webide) }

      it { is_expected.not_to be_any_ci_pipelines }
    end
  end

  describe '#external_pull_request_pipelines' do
    let_it_be(:pull_request_pipeline) do
      create(:ci_pipeline, project: project, source: :external_pull_request_event,
        external_pull_request: create(:external_pull_request, project: project))
    end

    it 'returns only external pull request pipelines' do
      expect(project_pipelines.external_pull_request_pipelines).to contain_exactly(pull_request_pipeline)
    end

    context 'when builds are disabled' do
      include_context 'when builds are disabled'

      it 'returns no pipelines' do
        expect(project_pipelines.external_pull_request_pipelines).to be_empty
      end
    end
  end

  describe '#auto_devops_pipelines' do
    let_it_be(:auto_devops_pipeline) { create(:ci_pipeline, :auto_devops_source, project: project) }

    before_all do
      create(:ci_pipeline, :auto_devops_source, project: project, source: :webide)
    end

    it 'returns only non-dangling Auto DevOps pipelines' do
      expect(project_pipelines.auto_devops_pipelines).to contain_exactly(auto_devops_pipeline)
    end

    context 'when builds are disabled' do
      include_context 'when builds are disabled'

      it 'returns no pipelines' do
        expect(project_pipelines.auto_devops_pipelines).to be_empty
      end
    end
  end
end
