# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Projects > Files > User forks to make changes', :js, feature_category: :source_code_management do
  include ProjectForksHelper

  let_it_be(:user) { create(:user, :with_namespace) }
  let_it_be_with_reload(:project) { create(:project, :public, :repository, reporters: user) }

  let(:tag_tree_path) { project_tree_path(project, 'v1.0.0') }

  before do
    sign_in(user)
    visit tag_tree_path
  end

  def upload_file_from_tag
    find('.add-to-tree').click
    click_link('Upload file')
  end

  context 'when the user has a fork with a renamed path' do
    before do
      fork_project(
        project, user,
        namespace: user.namespace,
        target_project: create(:project, namespace: user.namespace, path: 'renamed-fork', name: project.name)
      )
    end

    it 'uses the existing fork and says so' do
      expect do
        upload_file_from_tag

        expect(page).to have_current_path(tag_tree_path)
        expect(page).to have_text(
          "You're not allowed to make changes to this project directly. You already have a fork of this project " \
            "that you can make changes in, so you can submit a merge request. Try to upload a file again."
        )
      end.not_to change { user.namespace.projects.count }
    end
  end

  context 'when the user has an unrelated project at the same path' do
    let_it_be(:unrelated_project) { create(:project, namespace: user.namespace, path: project.path) }

    it 'explains the conflict' do
      expect do
        upload_file_from_tag

        expect(page).to have_text(
          "You already have a project at #{unrelated_project.full_path}, so a fork can't be created there. " \
            "Choose a different project slug."
        )
      end.not_to change { user.namespace.projects.count }

      expect(page).to have_link('Try to fork again', href: new_project_fork_path(project))
    end
  end
end
