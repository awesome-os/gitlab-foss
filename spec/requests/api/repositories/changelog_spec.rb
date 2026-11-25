# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::Repositories, feature_category: :source_code_management do
  let_it_be(:user) { create(:user) }
  let!(:maintainer) { create(:project_member, :maintainer, user: user, project: project) }

  describe 'GET /projects/:id/repository/changelog' do
    let(:project) { create(:project, :repository, creator: user) }

    it_behaves_like 'enforcing job token policies', :read_releases,
      allow_public_access_for_enabled_project_features: :repository do
      before do
        allow(Repositories::ChangelogService).to receive(:new)
          .and_return(instance_spy(Repositories::ChangelogService))
      end

      let(:request) do
        get api("/projects/#{source_project.id}/repository/changelog"),
          params: { version: '1.0.0', job_token: target_job.token }
      end
    end

    it 'generates the changelog for a version' do
      spy = instance_spy(::Repositories::ChangelogService)
      release_notes = 'Release notes'

      allow(::Repositories::ChangelogService)
        .to receive(:new)
        .with(
          project,
          user,
          version: '1.0.0',
          from: 'foo',
          to: 'bar',
          date: DateTime.new(2020, 1, 1),
          trailer: 'Foo'
        )
        .and_return(spy)

      expect(spy).to receive(:execute).with(commit_to_changelog: false).and_return(release_notes)

      get(
        api("/projects/#{project.id}/repository/changelog", user),
        params: {
          version: '1.0.0',
          from: 'foo',
          to: 'bar',
          date: '2020-01-01',
          trailer: 'Foo'
        }
      )

      expect(response).to have_gitlab_http_status(:ok)
      expect(json_response['notes']).to eq(release_notes)
    end

    it 'returns generated changelog when using JOB-TOKEN auth' do
      spy = instance_spy(::Repositories::ChangelogService)
      release_notes = 'Release notes'

      allow(::Repositories::ChangelogService)
        .to receive(:new)
        .with(
          project,
          user,
          version: '1.0.0',
          from: 'foo',
          to: 'bar',
          date: DateTime.new(2020, 1, 1),
          trailer: 'Foo'
        )
        .and_return(spy)

      expect(spy).to receive(:execute).with(commit_to_changelog: false).and_return(release_notes)

      job = create(:ci_build, :running, project: project, user: user)

      get api("/projects/#{project.id}/repository/changelog"),
        params: {
          job_token: job.token,
          version: '1.0.0',
          from: 'foo',
          to: 'bar',
          date: '2020-01-01',
          trailer: 'Foo'
        }

      expect(response).to have_gitlab_http_status(:ok)
      expect(json_response['notes']).to eq(release_notes)
    end

    it 'supports leaving out the from and to attribute' do
      spy = instance_spy(::Repositories::ChangelogService)

      allow(::Repositories::ChangelogService)
        .to receive(:new)
        .with(
          project,
          user,
          version: '1.0.0',
          date: DateTime.new(2020, 1, 1),
          trailer: 'Foo'
        )
        .and_return(spy)

      expect(spy).to receive(:execute).with(commit_to_changelog: false)

      get(
        api("/projects/#{project.id}/repository/changelog", user),
        params: {
          version: '1.0.0',
          date: '2020-01-01',
          trailer: 'Foo'
        }
      )

      expect(response).to have_gitlab_http_status(:ok)
      expect(json_response['notes']).to be_present
    end

    it 'supports specified config file path' do
      spy = instance_spy(::Repositories::ChangelogService)

      expect(::Repositories::ChangelogService)
        .to receive(:new)
        .with(
          project,
          user,
          version: '1.0.0',
          from: 'foo',
          to: 'bar',
          date: DateTime.new(2020, 1, 1),
          trailer: 'Foo',
          config_file: 'specified_changelog_config.yml'
        )
        .and_return(spy)

      expect(spy).to receive(:execute).with(commit_to_changelog: false)

      get(
        api("/projects/#{project.id}/repository/changelog", user),
        params: {
          version: '1.0.0',
          from: 'foo',
          to: 'bar',
          date: '2020-01-01',
          trailer: 'Foo',
          config_file: 'specified_changelog_config.yml'
        }
      )

      expect(response).to have_gitlab_http_status(:ok)
    end

    it 'supports a config file ref' do
      spy = instance_spy(::Repositories::ChangelogService)

      expect(::Repositories::ChangelogService)
        .to receive(:new)
        .with(
          project,
          user,
          config_file_ref: 'branch',
          version: '1.0.0',
          trailer: 'Changelog'
        )
        .and_return(spy)

      expect(spy).to receive(:execute).with(commit_to_changelog: false)

      get(
        api("/projects/#{project.id}/repository/changelog", user),
        params: {
          version: '1.0.0',
          config_file_ref: 'branch'
        }
      )

      expect(response).to have_gitlab_http_status(:ok)
    end

    it 'rate limits user when thresholds hit' do
      allow(::Gitlab::ApplicationRateLimiter).to receive(:throttled?).and_return(true)

      get(
        api("/projects/#{project.id}/repository/changelog", user),
        params: {
          version: '1.0.0'
        }
      )

      expect(response).to have_gitlab_http_status(:too_many_requests)
    end

    context 'when version is empty' do
      it 'returns an error' do
        get(
          api("/projects/#{project.id}/repository/changelog", user),
          params: {
            version: nil
          }
        )

        expect(response).to have_gitlab_http_status(:bad_request)
      end
    end

    context 'when previous tag version does not exist' do
      it_behaves_like '422 response' do
        let(:request) { get api("/projects/#{project.id}/repository/changelog", user), params: { version: 'v0.0.0' } }
        let(:message) { 'Failed to generate the changelog: The commit start range is unspecified, and no previous tag could be found to use instead' }
      end
    end

    context 'with format extension' do
      let(:release_notes) { '## 1.0.0 (2020-01-01)' }

      before do
        allow_next_instance_of(::Repositories::ChangelogService) do |service|
          allow(service).to receive(:execute).with(commit_to_changelog: false).and_return(release_notes)
        end
      end

      it 'returns plain text markdown with .txt extension', :aggregate_failures do
        get(
          api("/projects/#{project.id}/repository/changelog.txt", user),
          params: { version: '1.0.0' }
        )

        expect(response).to have_gitlab_http_status(:ok)
        expect(response.content_type).to start_with('text/plain')
        expect(response.body).to eq(release_notes)
      end

      it 'returns 404 with an unsupported extension', :aggregate_failures do
        get(
          api("/projects/#{project.id}/repository/changelog.zip", user),
          params: { version: '1.0.0' }
        )

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    it_behaves_like 'authorizing granular token permissions', :read_repository_changelog do
      let(:boundary_object) { project }

      before do
        spy = instance_spy(::Repositories::ChangelogService, execute: 'Release notes')

        allow(::Repositories::ChangelogService)
          .to receive(:new)
          .and_return(spy)
      end

      let(:request) do
        get api("/projects/#{project.id}/repository/changelog", personal_access_token: pat),
          params: {
            version: '1.0.0'
          }
      end
    end
  end

  describe 'POST /projects/:id/repository/changelog' do
    let(:project) { create(:project, :repository, creator: user) }

    it 'generates the changelog for a version' do
      spy = instance_spy(::Repositories::ChangelogService)

      allow(::Repositories::ChangelogService)
        .to receive(:new)
        .with(
          project,
          user,
          version: '1.0.0',
          from: 'foo',
          to: 'bar',
          date: DateTime.new(2020, 1, 1),
          branch: 'kittens',
          trailer: 'Foo',
          file: 'FOO.md',
          message: 'Commit message'
        )
        .and_return(spy)

      allow(spy).to receive(:execute).with(commit_to_changelog: true)

      post(
        api("/projects/#{project.id}/repository/changelog", user),
        params: {
          version: '1.0.0',
          from: 'foo',
          to: 'bar',
          date: '2020-01-01',
          branch: 'kittens',
          trailer: 'Foo',
          file: 'FOO.md',
          message: 'Commit message'
        }
      )

      expect(response).to have_gitlab_http_status(:ok)
    end

    it 'supports leaving out the from and to attribute' do
      spy = instance_spy(::Repositories::ChangelogService)

      allow(::Repositories::ChangelogService)
        .to receive(:new)
        .with(
          project,
          user,
          version: '1.0.0',
          date: DateTime.new(2020, 1, 1),
          branch: 'kittens',
          trailer: 'Foo',
          file: 'FOO.md',
          message: 'Commit message'
        )
        .and_return(spy)

      expect(spy).to receive(:execute).with(commit_to_changelog: true)

      post(
        api("/projects/#{project.id}/repository/changelog", user),
        params: {
          version: '1.0.0',
          date: '2020-01-01',
          branch: 'kittens',
          trailer: 'Foo',
          file: 'FOO.md',
          message: 'Commit message'
        }
      )

      expect(response).to have_gitlab_http_status(:ok)
    end

    it 'produces an error when generating the changelog fails' do
      spy = instance_spy(::Repositories::ChangelogService)

      allow(::Repositories::ChangelogService)
        .to receive(:new)
        .with(
          project,
          user,
          version: '1.0.0',
          from: 'foo',
          to: 'bar',
          date: DateTime.new(2020, 1, 1),
          branch: 'kittens',
          trailer: 'Foo',
          file: 'FOO.md',
          message: 'Commit message'
        )
        .and_return(spy)

      allow(spy)
        .to receive(:execute)
        .and_raise(Gitlab::Changelog::Error.new('oops'))

      post(
        api("/projects/#{project.id}/repository/changelog", user),
        params: {
          version: '1.0.0',
          from: 'foo',
          to: 'bar',
          date: '2020-01-01',
          branch: 'kittens',
          trailer: 'Foo',
          file: 'FOO.md',
          message: 'Commit message'
        }
      )

      expect(response).to have_gitlab_http_status(:unprocessable_entity)
      expect(json_response['message']).to eq('Failed to generate the changelog: oops')
    end

    it "supports specified config file path" do
      spy = instance_spy(::Repositories::ChangelogService)

      expect(::Repositories::ChangelogService)
        .to receive(:new)
        .with(
          project,
          user,
          version: '1.0.0',
          from: 'foo',
          to: 'bar',
          date: DateTime.new(2020, 1, 1),
          branch: 'kittens',
          trailer: 'Foo',
          config_file: 'specified_changelog_config.yml',
          file: 'FOO.md',
          message: 'Commit message'
        )
        .and_return(spy)

      allow(spy).to receive(:execute).with(commit_to_changelog: true)

      post(
        api("/projects/#{project.id}/repository/changelog", user),
        params: {
          version: '1.0.0',
          from: 'foo',
          to: 'bar',
          date: '2020-01-01',
          branch: 'kittens',
          trailer: 'Foo',
          config_file: 'specified_changelog_config.yml',
          file: 'FOO.md',
          message: 'Commit message'
        }
      )

      expect(response).to have_gitlab_http_status(:ok)
    end

    it "supports specified config file ref" do
      spy = instance_spy(::Repositories::ChangelogService)

      expect(::Repositories::ChangelogService)
        .to receive(:new)
        .with(
          project,
          user,
          version: '1.0.0',
          trailer: 'Foo',
          file: 'FOO.md',
          config_file: 'specified_changelog_config.yml',
          config_file_ref: 'foo'
        )
        .and_return(spy)

      allow(spy).to receive(:execute).with(commit_to_changelog: true)

      post(
        api("/projects/#{project.id}/repository/changelog", user),
        params: {
          version: '1.0.0',
          trailer: 'Foo',
          file: 'FOO.md',
          config_file: 'specified_changelog_config.yml',
          config_file_ref: 'foo'
        }
      )

      expect(response).to have_gitlab_http_status(:ok)
    end

    it 'rate limits user when thresholds hit' do
      allow(::Gitlab::ApplicationRateLimiter).to receive(:throttled?).and_return(true)

      post(
        api("/projects/#{project.id}/repository/changelog", user),
        params: {
          version: '1.0.0'
        }
      )

      expect(response).to have_gitlab_http_status(:too_many_requests)
    end

    it_behaves_like 'authorizing granular token permissions', :create_repository_changelog do
      let(:boundary_object) { project }

      before do
        spy = instance_spy(::Repositories::ChangelogService)

        allow(::Repositories::ChangelogService)
          .to receive(:new)
          .and_return(spy)

        allow(spy).to receive(:execute).with(commit_to_changelog: true)
      end

      let(:request) do
        post api("/projects/#{project.id}/repository/changelog", personal_access_token: pat),
          params: {
            version: '1.0.0'
          }
      end
    end
  end
end
