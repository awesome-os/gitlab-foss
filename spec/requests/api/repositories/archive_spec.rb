# frozen_string_literal: true

require 'spec_helper'
require 'mime/types'

RSpec.describe API::Repositories, feature_category: :source_code_management do
  include WorkhorseHelpers

  let_it_be(:user) { create(:user) }
  let_it_be(:project, reload: true) { create(:project, :repository, creator: user) }
  let!(:maintainer) { create(:project_member, :maintainer, user: user, project: project) }
  let(:guest) { create(:user).tap { |u| create(:project_member, :guest, user: u, project: project) } }

  shared_examples 'returns 503 when Gitaly is unavailable' do |http_method:|
    using RSpec::Parameterized::TableSyntax

    # Gitaly errors (GRPC::Unavailable, GRPC::DeadlineExceeded, etc.) are wrapped by
    # Gitlab::Git::WrapsGitalyErrors into CommandError or CommandTimedOut before
    # reaching the API layer. CommandTimedOut is a subclass of CommandError.
    where(:exception_class) do
      [
        [Gitlab::Git::CommandError],
        [Gitlab::Git::CommandTimedOut]
      ]
    end

    with_them do
      it 'returns 503' do
        stub_gitaly_error

        send(http_method, api(route, user))

        expect(response).to have_gitlab_http_status(:service_unavailable)
      end
    end
  end

  describe "GET /projects/:id/repository/archive(.:format)?:sha" do
    include_context 'workhorse headers'

    let(:project_id) { CGI.escape(project.full_path) }
    let(:route) { "/projects/#{project_id}/repository/archive" }

    let(:storage_path) { Gitlab.config.gitlab.repository_downloads_path }
    let(:format) { 'tar.gz' }
    let(:path) { nil }
    let(:metadata) { project.repository.archive_metadata(nil, storage_path, format, append_sha: nil, path: path) }

    before do
      allow(::Gitlab::ApplicationRateLimiter).to receive(:throttled?).and_return(false)
    end

    def expected_archive_request(repository, metadata, path, include_lfs_blobs, exclude_paths = [])
      Base64.encode64(
        Gitaly::GetArchiveRequest.new(
          repository: repository.gitaly_repository,
          commit_id: metadata['CommitId'],
          prefix: metadata['ArchivePrefix'],
          format: Gitaly::GetArchiveRequest::Format::TAR_GZ,
          path: path,
          include_lfs_blobs: include_lfs_blobs,
          exclude: exclude_paths
        ).to_proto
      )
    end

    shared_examples_for 'repository archive' do
      # Default to the more restrictive visibility; public contexts override it.
      let(:cache_visibility) { 'private' }

      it 'returns the repository archive' do
        get api(route, current_user), headers: workhorse_headers

        expect(response).to have_gitlab_http_status(:ok)

        type, params = workhorse_send_data

        expect(type).to eq('git-archive')
        expect(params['ArchivePath']).to match(/#{project.path}-[^.]+\.tar.gz/)
        expect(params['GetArchiveRequest']).to eq(expected_archive_request(project.repository, metadata, path, true))
        expect(response.parsed_body).to be_empty
      end

      it 'returns the repository archive archive.zip' do
        get api("/projects/#{project_id}/repository/archive.zip", user), headers: workhorse_headers

        expect(response).to have_gitlab_http_status(:ok)

        type, params = workhorse_send_data

        expect(type).to eq('git-archive')
        expect(params['ArchivePath']).to match(/#{project.path}-[^.]+\.zip/)
      end

      it 'returns the repository archive archive.tar.bz2' do
        get api("/projects/#{project_id}/repository/archive.tar.bz2", user), headers: workhorse_headers

        expect(response).to have_gitlab_http_status(:ok)

        type, params = workhorse_send_data

        expect(type).to eq('git-archive')
        expect(params['ArchivePath']).to match(/#{project.path}-[^.]+\.tar.bz2/)
      end

      context 'when sha does not exist' do
        it_behaves_like '404 response' do
          let(:request) { get api("#{route}?sha=xxx", current_user), headers: workhorse_headers }
          let(:message) { '404 File Not Found' }
        end
      end

      context 'when include_lfs_blobs is false' do
        it 'returns the correct GetArchiveRequest' do
          get api("#{route}?include_lfs_blobs=false", current_user), headers: workhorse_headers

          expect(response).to have_gitlab_http_status(:ok)

          type, params = workhorse_send_data

          expect(type).to eq('git-archive')
          expect(params['ArchivePath']).to match(/#{project.path}-[^.]+\.tar.gz/)
          expect(params['GetArchiveRequest']).to eq(expected_archive_request(project.repository, metadata, path, false))
        end
      end

      context 'with exclude_paths present in params' do
        it 'returns the correct GetArchiveRequest' do
          get api("#{route}?exclude_paths=lib,test", current_user), headers: workhorse_headers

          expect(response).to have_gitlab_http_status(:ok)

          type, params = workhorse_send_data

          expect(type).to eq('git-archive')
          expect(params['ArchivePath']).to match(/#{project.path}-[^.]+\.tar.gz/)
          expect(params['GetArchiveRequest']).to eq(expected_archive_request(project.repository, metadata, path, true, %w[lib test]))
        end
      end

      it 'returns only a part of the repository with path set' do
        path = 'bar'
        get api("#{route}?path=#{path}", current_user), headers: workhorse_headers

        expect(response).to have_gitlab_http_status(:ok)

        type, params = workhorse_send_data

        expect(type).to eq('git-archive')
        expect(params['ArchivePath']).to match(/#{project.path}-[^.]+-#{path}\.tar.gz/)
      end

      describe 'rate limiting' do
        context 'when already over the rate limit' do
          before do
            allow(::Gitlab::ApplicationRateLimiter).to receive(:throttled?).and_return(true)
          end

          it 'returns 429 without calling Gitaly for metadata' do
            expect_next_instance_of(Gitlab::Repositories::ArchiveHeaderBuilder) do |builder|
              expect(builder).not_to receive(:metadata)
            end

            get api("/projects/#{project_id}/repository/archive.tar.bz2", user), headers: workhorse_headers

            expect(response).to have_gitlab_http_status(:too_many_requests)
            expect(response.headers['ETag']).to be_nil
          end
        end

        context 'when the request tips over the rate limit' do
          it 'returns 429 and clears cache headers', :aggregate_failures do
            peek_flags = []
            allow(::Gitlab::ApplicationRateLimiter).to receive(:throttled?) do |_key, **options|
              peek_flags << options[:peek]
              !options[:peek]
            end

            get api("/projects/#{project_id}/repository/archive.tar.bz2", user), headers: workhorse_headers

            expect(response).to have_gitlab_http_status(:too_many_requests)
            expect(response.headers['Cache-Control']).to eq('no-store')
            expect(response.headers['ETag']).to be_nil
            expect(peek_flags).to eq([true, true, nil])
          end
        end

        it 'rate limits by the cross-project per-user limit' do
          allow(::Gitlab::ApplicationRateLimiter).to receive(:throttled?) do |key, **options|
            key == :repositories_archive && !options[:peek]
          end

          get api("/projects/#{project_id}/repository/archive.tar.bz2", user), headers: workhorse_headers

          expect(response).to have_gitlab_http_status(:too_many_requests)
        end

        it 'returns 429 for an anonymous caller when the cross-project IP limit is reached' do
          skip 'only applies to unauthenticated requests' if current_user

          allow(::Gitlab::ApplicationRateLimiter).to receive(:throttled?) do |key, **options|
            key == :repositories_archive_unauthenticated && !options[:peek]
          end

          get api("/projects/#{project_id}/repository/archive.tar.bz2"), headers: workhorse_headers

          expect(response).to have_gitlab_http_status(:too_many_requests)
        end

        it 'does not rate limit HEAD requests even when over the limit' do
          allow(::Gitlab::ApplicationRateLimiter).to receive(:throttled?).and_return(true)

          head api(route, current_user), headers: workhorse_headers

          expect(response).to have_gitlab_http_status(:ok)
        end

        it 'does not increment the rate limit for conditional requests that return 304' do
          get api(route, current_user), headers: workhorse_headers
          etag = response.headers['ETag']

          peek_flags = []
          allow(::Gitlab::ApplicationRateLimiter).to receive(:throttled?) do |_key, **options|
            peek_flags << options[:peek]
            false
          end

          get api(route, current_user), headers: workhorse_headers.merge('If-None-Match' => etag)

          expect(response).to have_gitlab_http_status(:not_modified)
          expect(peek_flags).to eq([true, true])
        end

        it 'returns 429 for conditional requests when already over the limit' do
          get api(route, current_user), headers: workhorse_headers
          etag = response.headers['ETag']

          allow(::Gitlab::ApplicationRateLimiter).to receive(:throttled?).and_return(true)

          get api(route, current_user), headers: workhorse_headers.merge('If-None-Match' => etag)

          expect(response).to have_gitlab_http_status(:too_many_requests)
        end
      end

      it_behaves_like "hotlink interceptor" do
        let(:http_request) do
          get api(route, current_user), headers: workhorse_headers.merge(headers || {})
        end
      end

      context 'when a project is moved' do
        where(:url_suffix) do
          [
            %w[repository/archive],
            %w[repository/archive?sha=123],
            %w[repository/archive.zip],
            %w[repository/archive.zip?sha=123]
          ]
        end

        with_them do
          let(:redirect_route) { 'new/project/location' }
          let(:route) { "/projects/#{CGI.escape(redirect_route)}/#{url_suffix}" }
          let(:location) { "#{::Settings.gitlab.url}/api/v4/projects/#{project.id}/#{url_suffix}" }

          before do
            project.route.create_redirect(redirect_route)
          end

          it 'redirects to the new project location' do
            get api(route, current_user), headers: workhorse_headers

            expect(response).to have_gitlab_http_status(:moved_permanently)
            # We use `start_with?` instead of `eq` because `api` appends a
            # personal token to the query string.
            expect(response.headers['Location']).to start_with(location)
          end
        end
      end

      describe 'caching headers' do
        it 'sets a strong ETag and tuned Cache-Control header', :aggregate_failures do
          get api(route, current_user)

          expect(response).to have_gitlab_http_status(:ok)
          expect(response.headers['ETag']).to be_present
          expect(response.headers['Cache-Control']).to eq(
            "max-age=60, #{cache_visibility}, must-revalidate, " \
              "stale-while-revalidate=60, stale-if-error=300, s-maxage=60"
          )
        end

        it 'uses the immutable max-age when the ref is a commit SHA', :aggregate_failures do
          commit_id = project.repository.commit.id

          get api("#{route}?sha=#{commit_id}", current_user)

          expect(response).to have_gitlab_http_status(:ok)
          expect(response.headers['Cache-Control']).to start_with("max-age=3600, #{cache_visibility}")
        end

        it 'returns 304 Not Modified for a matching conditional request', :aggregate_failures do
          get api(route, current_user)

          etag = response.headers['ETag']
          expect(etag).to be_present

          get api(route, current_user), headers: { 'If-None-Match' => etag }

          expect(response).to have_gitlab_http_status(:not_modified)
        end

        it 'keeps the ETag stable across identical requests', :aggregate_failures do
          get api(route, current_user)
          first_etag = response.headers['ETag']

          get api(route, current_user)

          expect(first_etag).to be_present
          expect(response.headers['ETag']).to eq(first_etag)
        end

        it 'varies the ETag by parameters that change the archive contents', :aggregate_failures do
          etags = [
            route,
            "#{route}.zip",
            "#{route}?path=files",
            "#{route}?include_lfs_blobs=false",
            "#{route}?exclude_paths=lib,test"
          ].map do |url|
            get api(url, current_user)
            response.headers['ETag']
          end

          expect(etags).to all(be_present)
          expect(etags.uniq.size).to eq(etags.size)
        end

        it 'returns the same cache headers for HEAD as GET', :aggregate_failures do
          get api(route, current_user)
          get_etag = response.headers['ETag']
          get_cache_control = response.headers['Cache-Control']

          head api(route, current_user)

          expect(response).to have_gitlab_http_status(:ok)
          expect(response.headers['ETag']).to eq(get_etag)
          expect(response.headers['Cache-Control']).to eq(get_cache_control)
        end

        it 'does not generate an archive for HEAD on the 200 or 304 path', :aggregate_failures do
          expect(Gitlab::Workhorse).not_to receive(:send_git_archive)

          head api(route, current_user)
          etag = response.headers['ETag']

          expect(response).to have_gitlab_http_status(:ok)
          expect(etag).to be_present

          head api(route, current_user), headers: { 'If-None-Match' => etag }

          expect(response).to have_gitlab_http_status(:not_modified)
        end

        it 'resolves metadata once and hands it to Workhorse for the body', :aggregate_failures do
          # Passing the resolved metadata means Workhorse does not resolve the ref a
          # second time, so the ETag and the archive body describe the same commit.
          expect(Gitlab::Workhorse).to receive(:send_git_archive)
            .with(anything, a_hash_including(metadata: a_hash_including('CommitId')))
            .and_call_original

          get api(route, current_user)

          expect(response).to have_gitlab_http_status(:ok)
        end
      end
    end

    context 'when unauthenticated', 'and project is public' do
      it_behaves_like 'repository archive' do
        let(:project) { create(:project, :public, :repository) }
        let(:current_user) { nil }
        let(:cache_visibility) { 'public' }
      end
    end

    context 'when unauthenticated and project path has dots' do
      it_behaves_like 'repository archive' do
        let(:project) { create(:project, :public, :repository, path: 'path.with.dot') }
        let(:current_user) { nil }
        let(:cache_visibility) { 'public' }
      end
    end

    context 'when unauthenticated', 'and project is private' do
      it_behaves_like '404 response' do
        let(:request) { get api(route) }
        let(:message) { '404 Project Not Found' }
      end
    end

    context 'when authenticated', 'as a developer' do
      it_behaves_like 'repository archive' do
        let(:current_user) { user }
        # The default project is private, so archives must not be shared-cacheable.
        let(:cache_visibility) { 'private' }
      end
    end

    context 'when authenticated', 'as a guest' do
      it_behaves_like '403 response' do
        let(:request) { get api(route, guest), headers: workhorse_headers }
      end
    end

    context 'when authenticated', 'and project is internal' do
      let_it_be(:internal_project) { create(:project, :internal, :repository) }

      before_all do
        internal_project.add_developer(user)
      end

      it 'keeps Cache-Control private so shared caches never store it', :aggregate_failures do
        get api("/projects/#{internal_project.id}/repository/archive", user)

        expect(response).to have_gitlab_http_status(:ok)
        expect(response.headers['Cache-Control']).to eq(
          'max-age=60, private, must-revalidate, stale-while-revalidate=60, stale-if-error=300, s-maxage=60'
        )
      end
    end

    context 'when Gitaly is unavailable' do
      let(:stub_gitaly_error) do
        allow(Gitlab::Workhorse).to receive(:send_git_archive)
          .and_raise(exception_class, 'Gitaly error')
      end

      it_behaves_like 'returns 503 when Gitaly is unavailable', http_method: :get

      it 'does not leave the archive cache headers on a 503', :aggregate_failures do
        allow(Gitlab::Workhorse).to receive(:send_git_archive)
          .and_raise(Gitlab::Git::CommandError, 'Gitaly error')

        get api(route, user)

        expect(response).to have_gitlab_http_status(:service_unavailable)
        expect(response.headers['Cache-Control']).to eq('no-store')
        expect(response.headers['ETag']).to be_nil
      end
    end

    context 'when archive is not found' do
      before do
        allow(Gitlab::Workhorse).to receive(:send_git_archive)
          .and_raise(Gitlab::Workhorse::ArchiveNotFoundError, 'Archive not found')
      end

      it 'returns 404 and does not leave the archive cache headers on the response', :aggregate_failures do
        get api(route, user)

        expect(response).to have_gitlab_http_status(:not_found)
        expect(response.headers['Cache-Control']).to eq('no-store')
        expect(response.headers['ETag']).to be_nil
      end
    end

    context 'when repository is empty' do
      let_it_be(:project) { create(:project, :empty_repo, creator: user) }
      let_it_be(:maintainer) { create(:project_member, :maintainer, user: user, project: project) }

      it 'returns 404', :aggregate_failures do
        get api("/projects/#{project_id}/repository/archive.tar.bz2", user)

        expect(response).to have_gitlab_http_status(:not_found)
        expect(json_response['message']).to eq('404 File Not Found')
      end
    end

    context 'when the project has no repository' do
      let_it_be(:project) { create(:project, creator: user) }
      let_it_be(:maintainer) { create(:project_member, :maintainer, user: user, project: project) }

      it 'returns 404 and does not leave the archive cache headers on the response', :aggregate_failures do
        get api("/projects/#{project_id}/repository/archive.tar.gz", user)

        expect(response).to have_gitlab_http_status(:not_found)
        expect(json_response['message']).to eq('404 Repository Not Found')
        expect(response.headers['Cache-Control']).to eq('no-store')
        expect(response.headers['ETag']).to be_nil
      end
    end

    context 'when ref_type is provided' do
      it 'forwards ref_type to send_git_archive' do
        expect(Gitlab::Workhorse).to receive(:send_git_archive).with(
          project.repository,
          hash_including(ref_type: 'heads')
        ).and_call_original

        get api("#{route}?ref_type=heads", user)

        expect(response).to have_gitlab_http_status(:ok)
      end

      it 'rejects invalid ref_type values' do
        get api("#{route}?ref_type=invalid", user)

        expect(response).to have_gitlab_http_status(:bad_request)
      end
    end

    it_behaves_like 'authorizing granular token permissions', :read_repository_archive do
      let(:boundary_object) { project }
      let(:request) do
        get api(route, personal_access_token: pat), headers: workhorse_headers
      end
    end

    it_behaves_like 'enforcing job token policies', :read_repositories,
      allow_public_access_for_enabled_project_features: :repository do
      let(:request) do
        get api(route), params: { job_token: target_job.token }
      end
    end
  end

  describe 'HEAD /projects/:id/repository/archive' do
    include_context 'workhorse headers'

    let(:route) { "/projects/#{project.id}/repository/archive" }

    it 'returns 200 OK with headers for authenticated user' do
      expect(Gitlab::Workhorse).not_to receive(:send_git_archive)

      head api(route, user), headers: workhorse_headers

      expect(response).to have_gitlab_http_status(:ok)
      # Content-Type is aligned with Workhorse: application/octet-stream for non-zip formats
      expect(response.headers['Content-Type']).to include('application/octet-stream')
      expect(response.headers['Content-Disposition']).to include('attachment')
    end

    context 'when project is public' do
      let_it_be(:public_project) { create(:project, :public, :repository) }

      it 'returns 200 OK for unauthenticated user' do
        head api("/projects/#{public_project.id}/repository/archive"), headers: workhorse_headers

        expect(response).to have_gitlab_http_status(:ok)
        expect(response.headers['Content-Type']).to include('application/octet-stream')
      end
    end

    context 'with specific format' do
      it 'returns correct content type for zip' do
        head api("#{route}.zip", user), headers: workhorse_headers

        expect(response).to have_gitlab_http_status(:ok)
        expect(response.headers['Content-Type']).to include('application/zip')
      end
    end

    context 'when Gitaly is unavailable' do
      let(:stub_gitaly_error) do
        allow_next_instance_of(Gitlab::Repositories::ArchiveHeaderBuilder) do |builder|
          allow(builder).to receive(:metadata).and_raise(exception_class, 'Gitaly error')
        end
      end

      it_behaves_like 'returns 503 when Gitaly is unavailable', http_method: :head
    end

    context 'when archive is not found' do
      it 'returns 404' do
        allow_next_instance_of(Gitlab::Repositories::ArchiveHeaderBuilder) do |builder|
          allow(builder).to receive(:metadata).and_raise(Gitlab::Workhorse::ArchiveNotFoundError, 'Archive not found')
        end

        head api(route, user)

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end
  end
end
