# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'projects/empty', feature_category: :groups_and_projects do
  let(:user) { build(:user) }
  let(:project) do
    project_statistics = build(:project_statistics)
    project = build_stubbed(:project, :empty_repo, statistics: project_statistics)
    ProjectPresenter.new(project, current_user: user)
  end

  let(:can_admin_project_member) { true }

  before do
    allow(view).to receive(:can?).with(user, :invite_member, project).and_return(can_admin_project_member)
    allow(view).to receive_messages(experiment_enabled?: true, current_user: user)
    assign(:project, project)
  end

  context 'when user can push to the default branch' do
    before do
      allow(project).to receive(:can_current_user_push_to_default_branch?).and_return(true)
      stub_template 'projects/_sidebar.html.haml' => ''
    end

    it 'shows how to add files', :aggregate_failures do
      render

      expect(rendered).to have_selector('[data-testid="quick-actions-container"]')
      expect(rendered).to have_content('The repository for this project is empty')
      expect(rendered).to have_content('Add files in your browser, or push them with Git.')
      expect(rendered).to have_content('Push files from your computer with Git.')
      expect(rendered).to have_content('git clone')
      expect(rendered).not_to have_selector('[data-testid="empty-repository-no-push"]')
    end

    context 'when default branch name contains special shell characters' do
      let(:branch_name) { ';rm -rf /' }

      before do
        allow(project).to receive(:default_branch_or_main).and_return(branch_name)
      end

      it 'escapes the default branch name' do
        render

        expect(rendered).not_to have_content(branch_name)
        expect(rendered).to have_content(branch_name.shellescape)
      end
    end
  end

  context 'when user cannot push to the default branch' do
    before do
      allow(project).to receive(:can_current_user_push_to_default_branch?).and_return(false)
    end

    it 'shows who needs to add the first files instead of Git instructions', :aggregate_failures do
      render

      expect(rendered).to have_selector('[data-testid="empty-repository-no-push"]')
      expect(rendered).to have_css('h2', text: 'The repository for this project is empty')
      expect(rendered).not_to have_css('h1', text: 'The repository for this project is empty')
      expect(rendered).to have_content('Files appear here after someone with the Maintainer or Owner role adds them.')
      expect(rendered).to have_link('Who can add the first files?',
        href: help_page_path('user/project/repository/branches/default.md', anchor: 'protect-initial-default-branches'),
        class: 'gl-link-inline')
      expect(rendered).not_to have_selector('[data-testid="quick-actions-container"]')
      expect(rendered).not_to have_content('Command line instructions')
      expect(rendered).not_to have_content('git clone')
    end
  end

  context 'when project is archived' do
    let(:project) do
      ProjectPresenter.new(
        build_stubbed(:project, :empty_repo, :archived, statistics: build(:project_statistics)), current_user: user
      )
    end

    it 'shows archived notice' do
      render

      expect(rendered).to have_content('Archived')
    end

    it 'says files cannot be added when the user cannot push', :aggregate_failures do
      allow(project).to receive(:can_current_user_push_to_default_branch?).and_return(false)

      render

      expect(rendered).to have_text('Files cannot be added while this project is read-only.')
      expect(rendered).to have_no_link('Who can add the first files?')
    end
  end

  context 'with invite button on empty projects' do
    it 'shows invite members info', :aggregate_failures do
      render

      expect(rendered).to have_tracking(action: 'render', label: 'invite_members_empty_project')
      expect(rendered).to have_content('Invite your team')
      expect(rendered).to have_content('Add members to this project and start collaborating with your team.')
      expect(rendered).to have_selector('.js-invite-members-trigger')
      expect(rendered).to have_selector('[data-trigger-source=project_empty_page]')
    end

    context 'when user does not have permissions to invite members' do
      let(:can_admin_project_member) { false }

      it 'does not show invite member info', :aggregate_failures do
        render

        expect(rendered).not_to have_content('Invite your team')
        expect(rendered).not_to have_selector('.js-invite-members-trigger')
      end
    end
  end
end
