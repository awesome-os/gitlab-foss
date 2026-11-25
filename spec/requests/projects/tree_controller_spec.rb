# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Projects tree controller', feature_category: :source_code_management do
  describe 'GET show' do
    let_it_be(:project) { create(:project, :public, :repository) }

    def mount_points
      Nokogiri::HTML(response.body).css('#js-repository-app, #js-tree-list, #js-repository-blob-header-app')
        .map { |node| node['id'] }
    end

    context 'when repository_single_vue_app is enabled' do
      let_it_be(:user) { create(:user, :with_namespace) }

      before do
        sign_in(user)
        stub_feature_flags(repository_single_vue_app: user)
      end

      it 'renders only the single repository app mount point' do
        get project_tree_path(project, 'master')

        expect(response).to have_gitlab_http_status(:ok)
        expect(mount_points).to eq(['js-repository-app'])
      end
    end

    context 'when repository_single_vue_app is disabled' do
      before do
        stub_feature_flags(repository_single_vue_app: false)
      end

      it 'renders the legacy mount points' do
        get project_tree_path(project, 'master')

        expect(response).to have_gitlab_http_status(:ok)
        expect(mount_points).to contain_exactly('js-tree-list', 'js-repository-blob-header-app')
      end
    end
  end

  describe 'GET show with an ambiguous branch and tag ref' do
    let_it_be(:project) { create(:project, :public, :repository) }

    before do
      raise 'fixture changed: v1.1.0 must be both a branch and a tag' unless
        project.repository.branch_exists?('v1.1.0') && project.repository.tag_exists?('v1.1.0')
    end

    context 'when repository_single_vue_app is enabled' do
      let_it_be(:user) { create(:user, :with_namespace) }

      before do
        sign_in(user)
        stub_feature_flags(repository_single_vue_app: user)
      end

      it 'flags the ambiguous ref on the single repository app only', :aggregate_failures do
        get project_tree_path(project, 'v1.1.0')

        expect(response).to have_gitlab_http_status(:ok)
        expect(response.body).to have_css('#js-repository-app[data-ambiguous-ref="true"]')
        expect(response.body).to have_no_css('#js-ambiguous-ref-modal')
      end

      it 'does not flag the ref when ref_type is set' do
        get project_tree_path(project, 'v1.1.0', ref_type: 'heads')

        expect(response.body).to have_css('#js-repository-app[data-ambiguous-ref="false"]')
      end
    end

    context 'when repository_single_vue_app is disabled' do
      before do
        stub_feature_flags(repository_single_vue_app: false)
      end

      it 'renders the standalone ambiguous ref modal mount point' do
        get project_tree_path(project, 'v1.1.0')

        expect(response).to have_gitlab_http_status(:ok)
        expect(response.body).to have_css('#js-ambiguous-ref-modal[data-ambiguous="true"]')
      end
    end
  end

  describe 'GET show for an ambiguous branch and tag whose names embed a ref prefix' do
    def get_show(ref_type:)
      get project_tree_path(ambiguous_project, ambiguous_ref, ref_type: ref_type)
    end

    context 'with a branch named "refs/tags/release" alongside a tag "release"' do
      include_context 'with an ambiguous branch and tag fixture',
        branch_name: 'refs/tags/release', tag_name: 'release'

      let(:ambiguous_ref) { 'refs/tags/release' }

      it_behaves_like 'an ambiguous ref with divergent branch and tag content'
      it_behaves_like 'archive download links anchored to the ref_type', ref_type: 'heads'
      it_behaves_like 'archive download links not anchored to a ref_type'

      context 'when repository_single_vue_app is disabled' do
        before do
          stub_feature_flags(repository_single_vue_app: false)
        end

        it_behaves_like 'archive download links anchored to the ref_type',
          ref_type: 'heads', selector: '#js-repository-blob-header-app'
        it_behaves_like 'archive download links not anchored to a ref_type',
          selector: '#js-repository-blob-header-app'
      end
    end

    context 'with a tag named "refs/heads/release" alongside a branch "release"' do
      include_context 'with an ambiguous branch and tag fixture',
        branch_name: 'release', tag_name: 'refs/heads/release'

      let(:ambiguous_ref) { 'refs/heads/release' }

      it_behaves_like 'an ambiguous ref with divergent branch and tag content'
      it_behaves_like 'archive download links anchored to the ref_type', ref_type: 'tags'
      it_behaves_like 'archive download links not anchored to a ref_type'

      context 'when repository_single_vue_app is disabled' do
        before do
          stub_feature_flags(repository_single_vue_app: false)
        end

        it_behaves_like 'archive download links anchored to the ref_type',
          ref_type: 'tags', selector: '#js-repository-blob-header-app'
        it_behaves_like 'archive download links not anchored to a ref_type',
          selector: '#js-repository-blob-header-app'
      end
    end
  end
end
