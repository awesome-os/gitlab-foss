# frozen_string_literal: true

require 'spec_helper'

# Asserts each web access-token endpoint is wired with the right permission; the
# GranularTokenAuthorization mechanism itself is unit tested separately.
RSpec.describe 'Granular token authorization on the web access token path', feature_category: :permissions do
  let_it_be(:user) { create(:user, :with_namespace) }
  let_it_be(:group) { create(:group, :private, developers: user) }
  let_it_be(:project) { create(:project, :repository, :private, group: group, developers: user) }
  let_it_be(:application) { create(:oauth_application) }

  let(:headers) { { 'PRIVATE-TOKEN' => token.token } }

  subject(:request) { get path, headers: headers }

  shared_examples 'granular web access authorization' do
    context 'with a granular token carrying the permission on the boundary' do
      let(:token) { create(:granular_pat, user: user, boundary: ::Authz::Boundary.for(boundary), permissions: permission) }

      it 'allows access' do
        request

        expect(response).to have_gitlab_http_status(:ok)
      end
    end

    context 'with a granular token missing the permission' do
      let(:token) { create(:granular_pat, user: user) }

      it 'responds with not found' do
        request

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context 'with a legacy token' do
      let(:token) { create(:personal_access_token, user: user, scopes: %w[api]) }

      it 'allows access' do
        request

        expect(response).to have_gitlab_http_status(:ok)
      end
    end

    context 'with a granular OAuth access token' do
      let(:headers) { { 'Authorization' => "Bearer #{token.plaintext_token}" } }
      let(:token) { create(:oauth_access_token, :granular, resource_owner: user, application: application) }

      context 'when the consent grant carries the permission on the boundary' do
        before do
          create(:oauth_consent_grant, user: user, application: application,
            boundary: ::Authz::Boundary.for(boundary), permissions: permission)
        end

        it 'allows access' do
          request

          expect(response).to have_gitlab_http_status(:ok)
        end
      end

      context 'without a consent grant' do
        it 'responds with not found' do
          request

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end
    end

    context 'with a legacy OAuth access token' do
      let(:headers) { { 'Authorization' => "Bearer #{token.plaintext_token}" } }
      let(:token) { create(:oauth_access_token, resource_owner: user, application: application, scopes: ['api']) }

      it 'allows access' do
        request

        expect(response).to have_gitlab_http_status(:ok)
      end
    end
  end

  # On a public project, Authz::BoundaryPolicy admits a token without a matching
  # scope for any permission anonymous users hold. A sessionless request is served
  # as the token's user, so such a token is denied. The same request without a
  # token is served to anonymous users as before.
  shared_examples 'granular web access authorization on a public project' do
    context 'with a granular token without any scope' do
      let(:token) { create(:granular_pat, user: user) }

      it 'responds with not found' do
        request

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context 'with a granular token carrying the permission on the project' do
      let(:token) do
        create(:granular_pat, user: user, boundary: ::Authz::Boundary.for(public_project), permissions: permission)
      end

      it 'allows access' do
        request

        expect(response).to have_gitlab_http_status(:ok)
      end
    end

    context 'without a token' do
      let(:headers) { {} }

      it 'allows access' do
        request

        expect(response).to have_gitlab_http_status(:ok)
      end
    end
  end

  # A repository archive and a release link download return the same data to
  # every reader, so a token without a matching scope gets what an anonymous
  # request gets. `expect_download` checks the response of an allowed request.
  shared_examples 'granular web access on a public project, the same for every reader' do
    context 'with a granular token without any scope' do
      let(:token) { create(:granular_pat, user: user) }

      it 'gets what an anonymous request gets' do
        request

        expect_download
      end
    end

    context 'without a token' do
      let(:headers) { {} }

      it 'allows access' do
        request

        expect_download
      end
    end
  end

  # Where anonymous users cannot read it, the public access rule does not admit
  # the token, so it needs the permission.
  shared_examples 'granular web access on a public project, for members only' do
    context 'with a granular token without any scope' do
      let(:token) { create(:granular_pat, user: user) }

      it 'responds with not found' do
        request

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context 'with a granular token carrying the permission on the project' do
      let(:token) do
        create(:granular_pat, user: user, boundary: ::Authz::Boundary.for(public_project), permissions: permission)
      end

      it 'allows access' do
        request

        expect_download
      end
    end
  end

  describe 'repository archive download' do
    let(:boundary) { project }
    let(:permission) { :download_code }
    let(:path) { "/#{project.full_path}/-/archive/#{project.default_branch}/archive.zip" }

    it_behaves_like 'granular web access authorization'
  end

  describe 'repository archive download on a public project' do
    let(:permission) { :download_code }
    let(:path) { "/#{public_project.full_path}/-/archive/#{public_project.default_branch}/archive.zip" }

    def expect_download
      expect(response).to have_gitlab_http_status(:ok)
      expect(response.headers[Gitlab::Workhorse::SEND_DATA_HEADER]).to start_with('git-archive:')
    end

    context 'when anonymous users can download the code' do
      let_it_be(:public_project) { create(:project, :public, :repository, developers: user) }

      it_behaves_like 'granular web access on a public project, the same for every reader'
    end

    context 'when the repository is for project members only' do
      let_it_be(:public_project) { create(:project, :public, :repository, :repository_private, developers: user) }

      it_behaves_like 'granular web access on a public project, for members only'
    end
  end

  describe 'project releases feed' do
    let(:boundary) { project }
    let(:permission) { :read_release }
    let(:path) { "/#{project.full_path}/-/releases.atom" }

    it_behaves_like 'granular web access authorization'
  end

  describe 'project issues feed' do
    let(:boundary) { project }
    let(:permission) { :read_work_item }
    let(:path) { "/#{project.full_path}/-/issues.atom" }

    it_behaves_like 'granular web access authorization'
  end

  describe 'feeds on a public project' do
    let_it_be(:public_project) { create(:project, :public, developers: user) }
    let_it_be(:public_issue) { create(:issue, project: public_project) }

    let(:permission) { :read_work_item }

    describe 'project issues feed' do
      let(:path) { "/#{public_project.full_path}/-/issues.atom" }

      it_behaves_like 'granular web access authorization on a public project'
    end

    describe 'project issues calendar' do
      let(:path) { "/#{public_project.full_path}/-/issues.ics" }

      it_behaves_like 'granular web access authorization on a public project'
    end
  end

  describe 'group issues feed' do
    let(:boundary) { group }
    let(:permission) { :read_work_item }
    let(:path) { "/groups/#{group.full_path}/-/issues.atom" }

    it_behaves_like 'granular web access authorization'
  end

  describe 'project merge requests feed' do
    let(:boundary) { project }
    let(:permission) { :read_merge_request }
    let(:path) { "/#{project.full_path}/-/merge_requests.atom" }

    it_behaves_like 'granular web access authorization'
  end

  describe 'group merge requests feed' do
    let(:boundary) { group }
    let(:permission) { :read_merge_request }
    let(:path) { "/groups/#{group.full_path}/-/merge_requests.atom" }

    it_behaves_like 'granular web access authorization'
  end

  describe 'project commits feed' do
    let(:boundary) { project }
    let(:permission) { :read_code }
    let(:path) { project_commits_path(project, project.default_branch, format: :atom) }

    it_behaves_like 'granular web access authorization'
  end

  describe 'project tags feed' do
    let(:boundary) { project }
    let(:permission) { :read_code }
    let(:path) { project_tags_path(project, format: :atom) }

    it_behaves_like 'granular web access authorization'
  end

  describe 'project activity feed' do
    let(:boundary) { project }
    let(:permission) { :read_event }
    let(:path) { "/#{project.full_path}.atom" }

    it_behaves_like 'granular web access authorization'
  end

  describe 'group activity feed' do
    let(:boundary) { group }
    let(:permission) { :read_event }
    let(:path) { "/#{group.full_path}.atom" }

    it_behaves_like 'granular web access authorization'
  end

  # Authorized on the token-owner (user) boundary, not the viewed profile.
  describe 'user activity feed' do
    let(:boundary) { ::Authz::GranularScope::Access::USER }
    let(:permission) { :read_activity }
    let(:path) { "/#{user.username}.atom" }

    it_behaves_like 'granular web access authorization'
  end

  describe 'dashboard projects feed' do
    let(:boundary) { ::Authz::GranularScope::Access::USER }
    let(:permission) { :read_project }
    let(:path) { "/dashboard/projects.atom" }

    it_behaves_like 'granular web access authorization'
  end

  # The :design format maps to read_design, which is granted through the
  # Work Item: Read assignable permission rather than a standalone design
  # permission.
  describe 'design management images' do
    include DesignManagementTestHelpers

    let_it_be(:issue) { create(:issue, project: project) }

    let(:boundary) { project }
    let(:permission) { :read_work_item }

    before do
      enable_design_management
    end

    describe 'raw image' do
      let_it_be(:design) { create(:design, :with_file, issue: issue) }

      let(:path) { project_design_management_designs_raw_image_path(project, design) }

      it_behaves_like 'granular web access authorization'
    end

    describe 'resized image' do
      # Per-example on purpose: resized design images are served from
      # CarrierWave disk storage, and the suite deletes CarrierWave.root after
      # every example. A group-level (let_it_be) record outlives its stored
      # file, so the second example that serves it fails with
      # ActionController::MissingFile. Raw images are served from Git LFS,
      # which is not cleaned between examples, so the raw group can share one.
      let(:design) { create(:design, :with_smaller_image_versions, issue: issue) }
      let(:path) { project_design_management_designs_resized_image_path(project, design, id: 'v432x230') }

      it_behaves_like 'granular web access authorization'
    end

    describe 'raw image on a public project' do
      let_it_be(:public_project) { create(:project, :public) }
      let_it_be(:public_issue) { create(:issue, project: public_project) }
      let_it_be(:public_design) { create(:design, :with_file, issue: public_issue) }

      let(:path) { project_design_management_designs_raw_image_path(public_project, public_design) }

      it_behaves_like 'granular web access authorization on a public project'
    end
  end

  describe 'release downloads' do
    let_it_be_with_reload(:release_project) do
      create(:project, :repository, :private, group: group, developers: user)
    end

    let_it_be_with_reload(:release) { create(:release, project: release_project, tag: 'v1.0.0') }
    let!(:link) do
      create(:release_link, release: release, filepath: '/bin/asset',
        url: "https://#{Gitlab.config.gitlab.host}:#{Gitlab.config.gitlab.port}/abcd")
    end

    let(:path) { "#{project_releases_path(release_project)}/#{release.tag}/downloads/bin/asset" }

    it 'denies a granular token without read_release' do
      token = create(:granular_pat, user: user)

      get path, headers: { 'PRIVATE-TOKEN' => token.token }

      expect(response).to have_gitlab_http_status(:not_found)
    end

    it 'allows a granular token with read_release' do
      token = create(:granular_pat, user: user,
        boundary: ::Authz::Boundary.for(release_project), permissions: :read_release)

      get path, headers: { 'PRIVATE-TOKEN' => token.token }

      expect(response).to have_gitlab_http_status(:redirect)
    end
  end

  describe 'release downloads on a public project' do
    let(:permission) { :read_release }
    let(:path) { "#{project_releases_path(public_project)}/v1.0.0/downloads/bin/asset" }
    let(:link_url) { "https://#{Gitlab.config.gitlab.host}:#{Gitlab.config.gitlab.port}/abcd" }

    before do
      release = create(:release, project: public_project, tag: 'v1.0.0')
      create(:release_link, release: release, filepath: '/bin/asset', url: link_url)
    end

    def expect_download
      expect(response).to redirect_to(link_url)
    end

    context 'when anonymous users can read releases' do
      let_it_be_with_reload(:public_project) { create(:project, :public, :repository, developers: user) }

      it_behaves_like 'granular web access on a public project, the same for every reader'
    end

    context 'when releases are for project members only' do
      let_it_be_with_reload(:public_project) do
        create(:project, :public, :repository, developers: user).tap do |project|
          project.project_feature.update!(releases_access_level: ProjectFeature::PRIVATE)
        end
      end

      it_behaves_like 'granular web access on a public project, for members only'
    end
  end

  # Redirects on success, so we assert the granular gate directly.
  describe 'personal access token expiry calendar' do
    let(:path) { "/-/user_settings/personal_access_tokens.ics" }

    it 'denies a granular token without read_personal_access_token' do
      token = create(:granular_pat, user: user)

      get path, headers: { 'PRIVATE-TOKEN' => token.token }

      expect(response).to have_gitlab_http_status(:not_found)
    end

    it 'allows a granular token with read_personal_access_token' do
      token = create(:granular_pat, user: user,
        boundary: ::Authz::Boundary.for(::Authz::GranularScope::Access::USER),
        permissions: :read_personal_access_token)

      get path, headers: { 'PRIVATE-TOKEN' => token.token }

      expect(response).to have_gitlab_http_status(:redirect)
    end
  end
end
