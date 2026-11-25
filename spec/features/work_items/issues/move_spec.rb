# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'issue move to another project', :js, feature_category: :team_planning do
  include ListboxHelpers

  let(:user) { create(:user) }
  let_it_be(:old_project) { create(:project, :repository) }
  let(:text) { 'Some issue description' }

  let(:issue) do
    create(:issue, description: text, project: old_project, author: user)
  end

  before do
    sign_in(user)
  end

  context 'user does not have permission to move issue' do
    before do
      old_project.add_guest(user) # rubocop:disable RSpec/BeforeAllRoleAssignment -- user is a per-example let, not available in before_all

      visit issue_path(issue)
    end

    it 'moving issue to another project not allowed' do
      click_button 'More actions', match: :first

      expect(page).not_to have_button 'Move'
    end
  end

  context 'user has permission to move issue' do
    let!(:mr) { create(:merge_request, source_project: old_project) }
    let(:new_project) { create(:project) }
    let(:new_project_search) { create(:project) }
    let(:text) { "Text with #{mr.to_reference}" }
    let(:cross_reference) { old_project.to_reference_base(new_project) }

    before do
      old_project.add_reporter(user) # rubocop:disable RSpec/BeforeAllRoleAssignment -- user is a per-example let, not available in before_all
      new_project.add_reporter(user)

      visit issue_path(issue)
    end

    it 'moving issue to another project' do
      click_button 'More actions', match: :first
      click_button 'Move'
      click_button 'Select project'
      find('[role="option"]', match: :first)
      send_keys :down, :enter
      select 'Issue', from: 'Type'
      click_button 'Move'

      expect(page).to have_content("Text with #{cross_reference}#{mr.to_reference}")
      expect(page).to have_content("moved from #{cross_reference}#{issue.to_reference}")
      expect(page).to have_content(issue.title)
      expect(page).to have_current_path(%r{#{project_path(new_project)}})
    end

    it 'searching project dropdown' do
      new_project_search.add_reporter(user)

      click_button 'More actions', match: :first
      click_button 'Move'
      click_button 'Select project'

      expect_listbox_item(new_project.name)

      send_keys new_project_search.name

      expect_listbox_item(new_project_search.name)
      expect_no_listbox_item(new_project.name)
    end

    context 'issue has been already moved' do
      let(:new_issue) { create(:issue, project: new_project) }
      let(:issue) do
        create(:issue, project: old_project, author: user, moved_to: new_issue)
      end

      it 'there is no option to move the already-moved issue' do
        click_button 'More actions', match: :first

        expect(page).not_to have_button('Move')
      end
    end
  end

  private

  def issue_path(issue)
    project_issue_path(issue.project, issue)
  end
end
