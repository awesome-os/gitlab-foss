# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::NpmInstancePackages, feature_category: :package_registry do
  # We need to create a subgroup with the same name as the hosting group.
  # It has to be created first to exhibit this bug: https://gitlab.com/gitlab-org/gitlab/-/issues/321958
  let_it_be(:another_namespace) { create(:group, :public) }
  let_it_be(:similarly_named_group) { create(:group, :public, parent: another_namespace, name: 'test-group') }

  include_context 'npm api setup'

  describe 'GET /api/v4/packages/npm/*package_name' do
    let(:url) { api("/packages/npm/#{package_name}") }

    subject { get(url) }

    it_behaves_like 'handling get metadata requests', scope: :instance
    it_behaves_like 'rejects invalid package names'
    it_behaves_like 'handling get metadata requests for packages in multiple projects'
    it_behaves_like 'handling get metadata requests from the project metadata cache'

    context 'with an unscoped package name and request forwarding disabled' do
      include_context 'dependency proxy helpers context'

      let(:package_name) { 'unscoped-package' }

      before do
        set_npm_package_requests_forwarding(false, :instance)
      end

      it 'returns not found' do
        get(url)

        expect(response).to have_gitlab_http_status(:not_found)
      end

      context 'when npm_allow_packages_in_multiple_projects is disabled' do
        before do
          stub_feature_flags(npm_allow_packages_in_multiple_projects: false)
        end

        it 'returns not found' do
          get(url)

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end
    end
  end

  describe 'GET /api/v4/packages/npm/-/package/*package_name/dist-tags' do
    it_behaves_like 'handling get dist tags requests', scope: :instance do
      let(:url) { api("/packages/npm/-/package/#{package_name}/dist-tags") }
    end

    it_behaves_like 'authorizing granular token permissions', :read_npm_package_tag do
      let(:boundary_object) { project }
      let(:request) do
        get api("/packages/npm/-/package/#{package_name}/dist-tags", personal_access_token: pat)
      end

      before do
        project.add_developer(user)
      end
    end
  end

  describe 'PUT /api/v4/packages/npm/-/package/*package_name/dist-tags/:tag' do
    it_behaves_like 'handling create dist tag requests', scope: :instance do
      let(:url) { api("/packages/npm/-/package/#{package_name}/dist-tags/#{tag_name}") }
    end

    it_behaves_like 'authorizing granular token permissions', :create_npm_package_tag do
      let(:tag_name) { 'test' }
      let(:boundary_object) { project }
      let(:request) do
        put api("/packages/npm/-/package/#{package_name}/dist-tags/#{tag_name}", personal_access_token: pat),
          env: { 'api.request.body': package.version }
      end

      before do
        project.add_developer(user)
      end
    end

    it_behaves_like 'enqueue a worker to sync a npm metadata cache' do
      let(:tag_name) { 'test' }
      let(:url) { api("/packages/npm/-/package/#{package_name}/dist-tags/#{tag_name}") }
      let(:env) { { 'api.request.body': package.version } }
      let(:headers) { build_token_auth_header(personal_access_token.token) }

      subject { put(url, env: env, headers: headers) }
    end
  end

  describe 'DELETE /api/v4/packages/npm/-/package/*package_name/dist-tags/:tag' do
    it_behaves_like 'handling delete dist tag requests', scope: :instance do
      let(:url) { api("/packages/npm/-/package/#{package_name}/dist-tags/#{tag_name}") }
    end

    it_behaves_like 'authorizing granular token permissions', :delete_npm_package_tag do
      let_it_be(:package_tag) { create(:packages_tag, package: package) }

      let(:tag_name) { package_tag.name }
      let(:boundary_object) { project }
      let(:request) do
        delete api("/packages/npm/-/package/#{package_name}/dist-tags/#{tag_name}", personal_access_token: pat)
      end

      before do
        project.add_maintainer(user)
      end
    end

    it_behaves_like 'enqueue a worker to sync a npm metadata cache' do
      let_it_be(:package_tag) { create(:packages_tag, package: package) }

      let(:tag_name) { package_tag.name }
      let(:url) { api("/packages/npm/-/package/#{package_name}/dist-tags/#{tag_name}") }
      let(:headers) { build_token_auth_header(personal_access_token.token) }

      subject { delete(url, headers: headers) }
    end
  end

  describe 'POST /api/v4/packages/npm/-/npm/v1/security/advisories/bulk' do
    it_behaves_like 'handling audit request', path: 'advisories/bulk', scope: :instance do
      let(:url) { api('/packages/npm/-/npm/v1/security/advisories/bulk') }
    end
  end

  describe 'POST /api/v4/packages/npm/-/npm/v1/security/audits/quick' do
    it_behaves_like 'handling audit request', path: 'audits/quick', scope: :instance do
      let(:url) { api('/packages/npm/-/npm/v1/security/audits/quick') }
    end
  end
end
