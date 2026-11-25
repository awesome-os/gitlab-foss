# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::Repositories, feature_category: :source_code_management do
  include RepoHelpers

  let_it_be(:user) { create(:user) }
  let_it_be(:project, reload: true) { create(:project, :repository, creator: user) }
  let!(:maintainer) { create(:project_member, :maintainer, user: user, project: project) }
  let(:guest) { create(:user).tap { |u| create(:project_member, :guest, user: u, project: project) } }

  describe "GET /projects/:id/repository/blobs/:sha" do
    let(:route) { "/projects/#{project.id}/repository/blobs/#{sample_blob.oid}" }

    shared_examples_for 'repository blob' do
      it 'returns blob attributes as json' do
        stub_const("Gitlab::Git::Blob::MAX_DATA_DISPLAY_SIZE", 5)

        get api(route, current_user)

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response['size']).to eq(111)
        expect(json_response['encoding']).to eq("base64")
        expect(json_response['sha']).to eq(sample_blob.oid)

        content = Base64.decode64(json_response['content'])
        expect(content.lines.first).to eq("class Commit\n")
        expect(content).to eq(project.repository.gitaly_blob_client.get_blob(oid: sample_blob.oid, limit: -1).data)
      end

      context 'when sha does not exist' do
        it_behaves_like '404 response' do
          let(:request) { get api(route.sub(sample_blob.oid, 'abcd9876'), current_user) }
          let(:message) { '404 Blob Not Found' }
        end
      end

      context 'when repository is disabled' do
        include_context 'disabled repository'

        it_behaves_like '403 response' do
          let(:request) { get api(route, current_user) }
        end
      end

      context 'when a large blob is requested' do
        it 'rate limits user when thresholds hit' do
          stub_const("API::Helpers::BlobHelpers::MAX_BLOB_SIZE", 5)
          allow(::Gitlab::ApplicationRateLimiter).to receive(:throttled_request?).and_return(true)

          get api(route, current_user)

          expect(response).to have_gitlab_http_status(:too_many_requests)
        end
      end
    end

    context 'when unauthenticated', 'and project is public' do
      it_behaves_like 'repository blob' do
        let_it_be_with_reload(:project) { create(:project, :public, :repository) }
        let(:current_user) { nil }
      end
    end

    context 'when unauthenticated', 'and project is private' do
      it_behaves_like '404 response' do
        let(:request) { get api(route) }
        let(:message) { '404 Project Not Found' }
      end
    end

    context 'when authenticated', 'as a developer' do
      it_behaves_like 'repository blob' do
        let(:current_user) { user }
      end
    end

    context 'when authenticated', 'as a guest' do
      it_behaves_like '403 response' do
        let(:request) { get api(route, guest) }
      end
    end

    it_behaves_like 'authorizing granular token permissions', :read_repository_blob do
      let(:boundary_object) { project }
      let(:request) do
        get api(route, personal_access_token: pat)
      end
    end
  end

  describe "GET /projects/:id/repository/blobs/:sha/raw" do
    include_context 'workhorse headers'

    let(:route) { "/projects/#{project.id}/repository/blobs/#{sample_blob.oid}/raw" }

    shared_examples_for 'repository raw blob' do
      it 'returns the repository raw blob' do
        expect(Gitlab::Workhorse).to receive(:send_git_blob) do |_, blob|
          expect(blob.id).to eq(sample_blob.oid)
          expect(blob.loaded_size).to eq(0)

          [Gitlab::Workhorse::SEND_DATA_HEADER, "git-blob:#{blob.id}"]
        end

        get api(route, current_user), headers: workhorse_headers

        expect(response).to have_gitlab_http_status(:ok)
        expect(headers[Gitlab::Workhorse::DETECT_HEADER]).to eq "true"
        expect(response.parsed_body).to be_empty
      end

      it 'sets inline content disposition by default' do
        get api(route, current_user), headers: workhorse_headers

        expect(headers['Content-Disposition']).to eq 'inline'
      end

      it 'defines an uncached header response' do
        get api(route, current_user), headers: workhorse_headers

        expect(response.headers["Cache-Control"]).to eq("max-age=0, private, must-revalidate, no-store, no-cache")
        expect(response.headers["Expires"]).to eq("Fri, 01 Jan 1990 00:00:00 GMT")
      end

      context 'when sha does not exist' do
        it_behaves_like '404 response' do
          let(:request) { get api(route.sub(sample_blob.oid, 'abcd9876'), current_user), headers: workhorse_headers }
          let(:message) { '404 Blob Not Found' }
        end
      end

      context 'when repository is disabled' do
        include_context 'disabled repository'

        it_behaves_like '403 response' do
          let(:request) { get api(route, current_user), headers: workhorse_headers }
        end
      end
    end

    context 'when unauthenticated', 'and project is public' do
      it_behaves_like 'repository raw blob' do
        let_it_be_with_reload(:project) { create(:project, :public, :repository) }
        let(:current_user) { nil }
      end
    end

    context 'when unauthenticated', 'and project is private' do
      it_behaves_like '404 response' do
        let(:request) { get api(route) }
        let(:message) { '404 Project Not Found' }
      end
    end

    context 'when authenticated', 'as a developer' do
      it_behaves_like 'repository raw blob' do
        let(:current_user) { user }
      end
    end

    context 'when authenticated', 'as a guest' do
      it_behaves_like '403 response' do
        let(:request) { get api(route, guest), headers: workhorse_headers }
      end
    end

    it_behaves_like 'authorizing granular token permissions', :read_repository_blob do
      let(:boundary_object) { project }
      let(:request) do
        get api(route, personal_access_token: pat), headers: workhorse_headers
      end
    end
  end

  describe 'POST /projects/:id/repository/blobs/batch' do
    let(:route) { "/projects/#{project.id}/repository/blobs/batch" }

    before do
      allow(::Gitlab::ApplicationRateLimiter).to receive(:throttled?).and_return(false)
    end

    shared_examples 'batch blobs' do
      it 'returns contents of multiple files' do
        post api(route, current_user), params: { files: [{ path: 'README.md' }, { path: 'CHANGELOG' }] }

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response).to be_an(Array)
        expect(json_response.size).to eq(2)
        expect(json_response.first['path']).to eq('README.md')
        expect(json_response.first['encoding']).to eq('base64')
        expect(json_response.first['size']).to be > 0
        expect(json_response.first['truncated']).to be(false)
        expect(json_response.first['content']).to be_present
      end

      it 'skips files that do not exist' do
        post api(route, current_user), params: { files: [{ path: 'README.md' }, { path: 'nonexistent.txt' }] }

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response.size).to eq(1)
        expect(json_response.first['path']).to eq('README.md')
      end

      it 'supports specifying ref per file' do
        post api(route, current_user), params: { files: [{ path: 'README.md', ref: 'master' }] }

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response.size).to eq(1)
        expect(json_response.first['ref']).to eq('master')
      end

      it 'falls back to the default branch when ref is blank' do
        post api(route, current_user), params: { files: [{ path: 'README.md', ref: '' }] }

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response.size).to eq(1)
        expect(json_response.first['ref']).to eq(project.default_branch)
      end

      it 'returns both entries when same path is requested at different refs' do
        post api(route, current_user),
          params: { files: [{ path: 'README.md', ref: 'master' }, { path: 'README.md', ref: 'feature' }] }

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response.size).to eq(2)
        expect(json_response.map { |r| r['ref'] }).to eq(%w[master feature])
      end

      it 'attributes the blob to the correct ref when the same path is missing at an earlier ref' do
        # .gitattributes exists on master but not on the feature branch. Requesting the
        # missing ref first must not cause master's content to be mislabeled as `feature`.
        post api(route, current_user),
          params: { files: [{ path: '.gitattributes', ref: 'feature' }, { path: '.gitattributes', ref: 'master' }] }

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response.size).to eq(1)
        expect(json_response.first['ref']).to eq('master')
        expect(json_response.first['path']).to eq('.gitattributes')
        expect(json_response.first['content']).to be_present
      end

      it 'returns 400 when files parameter is missing' do
        post api(route, current_user)

        expect(response).to have_gitlab_http_status(:bad_request)
      end

      it 'returns 400 when files array is empty' do
        post api(route, current_user), params: { files: [] }

        expect(response).to have_gitlab_http_status(:bad_request)
      end

      it 'returns 400 when too many files are requested' do
        files = (1..21).map { |i| { path: "file#{i}.txt" } }
        post api(route, current_user), params: { files: files }

        expect(response).to have_gitlab_http_status(:bad_request)
      end

      it 'returns 400 when a ref is invalid' do
        post api(route, current_user), params: { files: [{ path: 'README.md', ref: 'invalid ref!' }] }

        expect(response).to have_gitlab_http_status(:bad_request)
        expect(json_response['message']).to include('Invalid ref')
      end

      it 'returns 400 when a path traverses outside the repository' do
        post api(route, current_user), params: { files: [{ path: '../../../etc/passwd' }] }

        expect(response).to have_gitlab_http_status(:bad_request)
      end

      it 'rate limits the user when the threshold is hit' do
        allow(::Gitlab::ApplicationRateLimiter).to receive(:throttled?).and_return(true)

        post api(route, current_user), params: { files: [{ path: 'README.md' }] }

        expect(response).to have_gitlab_http_status(:too_many_requests)
      end

      context 'when repository is disabled' do
        include_context 'disabled repository'

        it_behaves_like '403 response' do
          let(:request) { post api(route, current_user), params: { files: [{ path: 'README.md' }] } }
        end
      end
    end

    context 'when authenticated', 'as a developer' do
      it_behaves_like 'batch blobs' do
        let(:current_user) { user }
      end
    end

    context 'when authenticated', 'as a guest' do
      it_behaves_like '403 response' do
        let(:request) { post api(route, guest), params: { files: [{ path: 'README.md' }] } }
      end
    end

    context 'when authenticated using a token with ai_workflows scope' do
      let(:oauth_token) { create(:oauth_access_token, user: user, scopes: [:ai_workflows]) }

      it 'returns contents of multiple files' do
        post api(route, oauth_access_token: oauth_token), params: { files: [{ path: 'README.md' }] }

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response.first['path']).to eq('README.md')
      end

      it 'still refuses other POST routes in this API' do
        post api("/projects/#{project.id}/repository/changelog", oauth_access_token: oauth_token),
          params: { version: '1.0.0' }

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end

    context 'when unauthenticated', 'and project is private' do
      it_behaves_like '404 response' do
        let(:request) { post api(route), params: { files: [{ path: 'README.md' }] } }
        let(:message) { '404 Project Not Found' }
      end
    end

    context 'when unauthenticated', 'and project is public' do
      let_it_be(:public_project) { create(:project, :public, :repository) }
      let(:route) { "/projects/#{public_project.id}/repository/blobs/batch" }

      it_behaves_like '401 response' do
        let(:request) { post api(route), params: { files: [{ path: 'README.md' }] } }
      end

      it 'returns 401 before validating parameters' do
        post api(route), params: { files: [] }

        expect(response).to have_gitlab_http_status(:unauthorized)
      end
    end

    it_behaves_like 'authorizing granular token permissions', :read_repository_blob do
      let(:boundary_object) { project }
      let(:request) do
        post api(route, personal_access_token: pat), params: { files: [{ path: 'README.md' }] }
      end
    end

    context 'when the repository_blobs_batch_api feature flag is disabled' do
      before do
        stub_feature_flags(repository_blobs_batch_api: false)
      end

      it_behaves_like '404 response' do
        let(:request) { post api(route, user), params: { files: [{ path: 'README.md' }] } }
      end
    end
  end
end
