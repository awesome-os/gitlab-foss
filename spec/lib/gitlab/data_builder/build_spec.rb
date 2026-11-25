# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::DataBuilder::Build, feature_category: :integrations do
  let_it_be(:runner) { create(:ci_runner, :instance, :tagged_only) }
  let_it_be(:user) { create(:user, :public_email) }
  let_it_be(:pipeline) { create(:ci_pipeline, started_at: 1.hour.ago, finished_at: 1.minute.ago, name: 'Build pipeline') }
  let_it_be(:ci_build) { create(:ci_build, :finished, started_at: 1.hour.ago, finished_at: 1.minute.ago, pipeline: pipeline, runner: runner, user: user) }

  describe '.build' do
    around do |example|
      travel_to(Time.current) { example.run }
    end

    let(:data) do
      described_class.build(ci_build)
    end

    it { expect(data).to be_a(Hash) }
    it { expect(data[:ref]).to eq(ci_build.ref) }
    it { expect(data[:sha]).to eq(ci_build.sha) }
    it { expect(data[:tag]).to eq(ci_build.tag) }
    it { expect(data[:build_id]).to eq(ci_build.id) }
    it { expect(data[:build_status]).to eq(ci_build.status) }
    it { expect(data[:build_created_at]).to eq(ci_build.created_at) }
    it { expect(data[:build_started_at]).to eq(ci_build.started_at) }
    it { expect(data[:build_finished_at]).to eq(ci_build.finished_at) }
    it { expect(data[:build_created_at_iso]).to eq(ci_build.created_at.iso8601) }
    it { expect(data[:build_started_at_iso]).to eq(ci_build.started_at.iso8601) }
    it { expect(data[:build_finished_at_iso]).to eq(ci_build.finished_at.iso8601) }
    it { expect(data[:build_duration]).to eq(ci_build.duration) }
    it { expect(data[:build_queued_duration]).to eq(ci_build.queued_duration) }
    it { expect(data[:build_allow_failure]).to be(false) }
    it { expect(data[:build_failure_reason]).to eq(ci_build.failure_reason) }
    it { expect(data[:project_id]).to eq(ci_build.project.id) }
    it { expect(data[:project_name]).to eq(ci_build.project.full_name) }
    it { expect(data[:pipeline_id]).to eq(ci_build.pipeline.id) }
    it { expect(data[:retries_count]).to eq(ci_build.retries_count) }
    it { expect(data[:commit][:name]).to eq(pipeline.name) }

    it 'returns only the user id, name, username, avatar url and email' do
      expect(data[:user]).to eq(
        {
          id: user.id,
          name: user.name,
          username: user.username,
          avatar_url: user.avatar_url(only_path: false),
          email: user.email
        })
    end

    it { expect(data[:commit][:id]).to eq(ci_build.pipeline.id) }
    it { expect(data[:runner][:id]).to eq(ci_build.runner.id) }
    it { expect(data[:runner][:tags]).to match_array(%w[tag1 tag2]) }
    it { expect(data[:runner][:description]).to eq(ci_build.runner.description) }
    it { expect(data[:runner][:runner_type]).to eq(ci_build.runner.runner_type) }
    it { expect(data[:runner][:is_shared]).to eq(ci_build.runner.instance_type?) }
    it { expect(data[:project]).to eq(ci_build.project.hook_attrs(backward: false)) }
    it { expect(data[:environment]).to be_nil }

    context 'when retries_count is given' do
      let(:data) { described_class.build(ci_build, retries_count: 3) }

      it 'uses the given count instead of counting retries' do
        expect(ci_build).not_to receive(:retries_count)

        expect(data[:retries_count]).to eq(3)
      end
    end

    describe 'build_status_changed_at' do
      using RSpec::Parameterized::TableSyntax

      let(:timestamps) do
        {
          created_at: 5.hours.ago,
          queued_at: 4.hours.ago,
          started_at: 3.hours.ago,
          finished_at: 2.hours.ago,
          updated_at: 1.hour.ago
        }
      end

      let(:ci_build) { build_stubbed(:ci_build, status: status, pipeline: pipeline, **timestamps) }

      where(:status, :column) do
        'created'  | :created_at
        'pending'  | :queued_at
        'running'  | :started_at
        'success'  | :finished_at
        'failed'   | :finished_at
        'canceled' | :finished_at
        'skipped'  | :finished_at
        'manual'   | :updated_at
      end

      with_them do
        it 'uses the timestamp of the current status' do
          expect(data[:build_status_changed_at]).to eq(timestamps[column])
          expect(data[:build_status_changed_at_iso]).to eq(timestamps[column].iso8601)
        end
      end

      context 'when the column for the status is not set' do
        let(:status) { 'skipped' }
        let(:timestamps) { { created_at: 2.hours.ago, finished_at: nil, updated_at: 1.hour.ago } }

        it 'falls back to updated_at' do
          expect(data[:build_status_changed_at]).to eq(timestamps[:updated_at])
          expect(data[:build_status_changed_at_iso]).to eq(timestamps[:updated_at].iso8601)
        end
      end

      context 'when the build has no timestamps' do
        let(:ci_build) { build(:ci_build, :created, pipeline: pipeline, created_at: nil, updated_at: nil) }

        it 'returns nil for the timestamps', :aggregate_failures do
          expect(data[:build_created_at_iso]).to be_nil
          expect(data[:build_status_changed_at]).to be_nil
          expect(data[:build_status_changed_at_iso]).to be_nil
        end
      end
    end

    context 'when a Git commit is supplied' do
      let(:git_commit) do
        Commit.from_hash({
          id: pipeline.sha,
          message: 'Cached Git message',
          author_name: 'Commit author',
          author_email: 'commit-author@example.com'
        }, ci_build.project)
      end

      let(:data) { described_class.build(ci_build, git_commit: git_commit) }

      it 'uses its Git data without loading the pipeline commit', :aggregate_failures do
        expect(ci_build).not_to receive(:commit)
        expect(pipeline).not_to receive(:commit)

        expect(data[:commit]).to include(
          id: pipeline.id,
          name: pipeline.name,
          sha: pipeline.sha,
          message: 'Cached Git message',
          author_name: 'Commit author',
          author_email: 'commit-author@example.com',
          author_url: 'mailto:commit-author@example.com',
          status: pipeline.status,
          started_at: pipeline.started_at,
          finished_at: pipeline.finished_at
        )
      end

      context 'when the supplied commit is missing' do
        let(:git_commit) { nil }

        it 'preserves the missing-commit payload', :aggregate_failures do
          expect(ci_build).not_to receive(:commit)
          expect(pipeline).not_to receive(:commit)

          expect(data[:commit]).to include(
            id: pipeline.id, sha: pipeline.sha, message: nil,
            author_name: nil, author_email: nil, author_url: 'mailto:'
          )
        end
      end
    end

    describe '.status_changed_at' do
      let(:ci_build) do
        build_stubbed(:ci_build, :running, pipeline: pipeline, queued_at: 2.hours.ago, started_at: 1.hour.ago)
      end

      it 'uses the timestamp of the current status by default' do
        expect(described_class.status_changed_at(ci_build)).to eq(ci_build.started_at)
      end

      it 'uses the timestamp of the given status' do
        expect(described_class.status_changed_at(ci_build, 'pending')).to eq(ci_build.queued_at)
      end

      it 'returns nil for a past status without a timestamp column' do
        expect(described_class.status_changed_at(ci_build, 'manual')).to be_nil
      end

      it 'returns nil for a past status whose timestamp column is not set' do
        ci_build.queued_at = nil

        expect(described_class.status_changed_at(ci_build, 'pending')).to be_nil
      end
    end

    context 'when started_at and finished_at are not present' do
      let_it_be(:ci_build) { create(:ci_build, :pending, pipeline: pipeline, runner: runner, user: user) }

      it { expect(data[:build_started_at_iso]).to be_nil }
      it { expect(data[:build_finished_at_iso]).to be_nil }
    end

    it { expect(data[:source_pipeline]).to be_nil }

    it 'does not exceed number of expected queries' do
      ci_build # Make sure the Ci::Build model is created before recording.

      control = ActiveRecord::QueryRecorder.new(skip_cached: false) do
        b = Ci::Build.find(ci_build.id)
        described_class.build(b) # Don't use ci_build variable here since it has all associations loaded into memory
      end

      expect(control.count).to eq(16)
    end

    context 'commit author_url' do
      context 'when no commit present' do
        let(:build) { build(:ci_build) }

        it 'sets to mailing address of git_author_email' do
          expect(data[:commit][:author_url]).to eq("mailto:#{ci_build.pipeline.git_author_email}")
        end
      end

      context 'when commit present but has no author' do
        let(:ci_build) { build(:ci_build, :with_commit) }

        it 'sets to mailing address of git_author_email' do
          expect(data[:commit][:author_url]).to eq("mailto:#{ci_build.pipeline.git_author_email}")
        end
      end

      context 'when commit and author are present' do
        let(:ci_build) { build(:ci_build, :with_commit_and_author) }

        it 'sets to GitLab user url' do
          expect(data[:commit][:author_url]).to eq(Gitlab::Routing.url_helpers.user_url(username: ci_build.commit.author.username))
        end
      end

      context 'with environment' do
        let(:ci_build) { build(:ci_build, :teardown_environment) }

        it { expect(data[:environment][:name]).to eq(ci_build.expanded_environment_name) }
        it { expect(data[:environment][:action]).to eq(ci_build.environment_action) }
      end
    end

    context 'when the build job has an upstream' do
      let(:source_pipeline_attrs) { data[:source_pipeline] }

      shared_examples 'source pipeline attributes' do
        it 'has source pipeline attributes', :aggregate_failures do
          expect(source_pipeline_attrs[:pipeline_id]).to eq upstream_pipeline.id
          expect(source_pipeline_attrs[:job_id]).to eq pipeline.reload.source_bridge.id
          expect(source_pipeline_attrs[:project][:id]).to eq upstream_pipeline.project.id
          expect(source_pipeline_attrs[:project][:web_url]).to eq upstream_pipeline.project.web_url
          expect(source_pipeline_attrs[:project][:path_with_namespace]).to eq upstream_pipeline.project.full_path
        end
      end

      context 'in same project' do
        let_it_be(:upstream_pipeline) { create(:ci_pipeline, upstream_of: pipeline, project: ci_build.project) }

        it_behaves_like 'source pipeline attributes'
      end

      context 'in different project' do
        let_it_be(:upstream_pipeline) { create(:ci_pipeline, upstream_of: pipeline) }

        it_behaves_like 'source pipeline attributes'

        it { expect(source_pipeline_attrs[:project][:id]).not_to eq pipeline.project.id }
      end
    end

    it { expect(data[:commit][:finished_at]).to eq(ci_build.pipeline.finished_at) }
    it { expect(data[:commit][:started_at_iso]).to eq(ci_build.pipeline.started_at.iso8601) }
    it { expect(data[:commit][:finished_at_iso]).to eq(ci_build.pipeline.finished_at.iso8601) }
  end
end
