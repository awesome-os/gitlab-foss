# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'User views an empty project', feature_category: :groups_and_projects do
  include Features::InviteMembersModalHelpers

  let_it_be(:project) { create(:project, :empty_repo) }
  let_it_be(:user) { create(:user) }

  shared_examples 'allowing push to default branch' do
    let(:default_branch) { project.default_branch_or_main }

    it 'shows push-to-default-branch instructions' do
      visit project_path(project)

      expect(page).to have_content("git push --set-upstream origin #{default_branch}")
    end
  end

  shared_examples 'saying files cannot be added' do
    before do
      project.add_maintainer(user)
      sign_in(user)
    end

    it 'shows the read-only empty state instead of Git instructions', :aggregate_failures do
      visit project_path(project)

      expect(page).to have_text('Files cannot be added while this project is read-only.')
      expect(page).to have_no_link('Who can add the first files?')
      expect(page).to have_no_text('Command line instructions')
    end
  end

  context 'when user is a maintainer' do
    before do
      project.add_maintainer(user)
      sign_in(user)
    end

    it_behaves_like 'allowing push to default branch'

    it 'shows a link for inviting members and launches invite modal', :js do
      visit project_path(project)

      click_button 'Invite members'

      page.within invite_modal_selector do
        expect(page).to have_content("You're inviting members to the #{project.name} project")
      end
    end
  end

  context 'when user is a maintainer and the project is read-only' do
    context 'when the project is archived' do
      let_it_be(:project) { create(:project, :empty_repo, :archived) }

      it_behaves_like 'saying files cannot be added'
    end

    context 'when the project is scheduled for deletion' do
      let_it_be(:project) { create(:project, :empty_repo, :aimed_for_deletion) }

      it_behaves_like 'saying files cannot be added'
    end

    context 'when the project group is scheduled for deletion' do
      let_it_be(:group) { create(:group_with_deletion_schedule) }
      let_it_be(:project) { create(:project, :empty_repo, group: group) }

      it_behaves_like 'saying files cannot be added'
    end

    context 'when the project group is archived' do
      let_it_be(:group) { create(:group, :archived) }
      let_it_be(:project) { create(:project, :empty_repo, group: group) }

      it_behaves_like 'saying files cannot be added'
    end

    context 'when a parent group of the project group is archived' do
      let_it_be(:parent) { create(:group, :archived) }
      let_it_be(:group) { create(:group, parent: parent) }
      let_it_be(:project) { create(:project, :empty_repo, group: group) }

      it_behaves_like 'saying files cannot be added'
    end
  end

  context 'when user is an admin' do
    let_it_be(:user) { create(:user, :admin) }

    context 'when admin mode is enabled' do
      before do
        sign_in(user)
        enable_admin_mode!(user)
      end

      it_behaves_like 'allowing push to default branch'
    end

    context 'when admin mode is disabled' do
      it 'does not show push-to-master instructions' do
        visit project_path(project)

        expect(page).not_to have_content('git push --set-upstream origin')
      end
    end
  end

  context 'when user is a developer' do
    before do
      project.add_developer(user)
      sign_in(user)
    end

    it 'does not show push-to-master instructions nor invite members link', :aggregate_failures, :js do
      visit project_path(project)

      expect(page).not_to have_content('git push --set-upstream origin')
      expect(page).not_to have_button(text: 'Invite members')
    end

    it 'shows who can add the first files instead of Git instructions', :aggregate_failures do
      visit project_path(project)

      expect(page).to have_content('The repository for this project is empty')
      expect(page).to have_content('Files appear here after someone with the Maintainer or Owner role adds them.')
      expect(page).not_to have_content('Command line instructions')
    end

    context 'when developers can do the initial push' do
      before do
        stub_application_setting(
          default_branch_protection_defaults: Gitlab::Access::BranchProtection.protected_after_initial_push
        )
      end

      it_behaves_like 'allowing push to default branch'

      it 'shows how to add files' do
        visit project_path(project)

        expect(page).to have_content('Add files in your browser, or push them with Git.')
      end
    end
  end
end
