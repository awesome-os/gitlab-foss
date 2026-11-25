# frozen_string_literal: true

RSpec.shared_examples 'work item time tracker' do
  include Spec::Support::Helpers::ModalHelpers

  before do
    project.add_maintainer(maintainer)
    sign_in(maintainer)
  end

  context 'when the work item has an estimate' do
    before do
      issuable.update!(time_estimate: 129.hours.to_i)
      visit project_issue_path(project, issuable)
    end

    it 'updates the estimate from the edit estimate modal' do
      click_button '16d 1h'

      within_modal do
        expect(page).to have_css('h2', text: 'Edit time estimate')

        fill_in 'Estimate', with: '3w 3d'
        click_button 'Save'
      end

      within_testid('work-item-time-tracking') do
        expect(page).to have_text 'Estimate 18d'
        expect(page).to have_button '18d'
      end
    end
  end

  it 'shows time tracking report and removes time log when deleted',
    quarantine: { issue: 'https://gitlab.com/gitlab-org/quality/test-failure-issues/-/issues/44471' } do
    visit project_issue_path(project, issuable)
    add_comment('/estimate 1w')
    add_comment("/spend 1d #{5.days.ago.strftime('%F')}")
    click_button 'Add time entry'

    within_modal do
      expect(page).to have_css('h2', text: 'Add time entry')

      fill_in 'Time spent', with: '3d'
      click_button 'Save'
    end

    click_button '4d'

    within_modal do
      expect(page).to have_css('h2', text: 'Time tracking report')
      expect(page).to have_css('tbody tr:nth-child(1)', text: '3d')
      expect(page).to have_css('tbody tr:nth-child(2)', text: '1d')
      expect(page).to have_css('tfoot', text: '4d') # total time spent

      page.within 'tbody tr:nth-child(2)' do
        click_button 'Delete time spent'
      end

      expect(page).to have_css('tbody tr:nth-child(1)', text: '3d')
      expect(page).not_to have_css('tbody tr:nth-child(2)')
      expect(page).to have_css('tfoot', text: '3d') # total time spent

      click_button 'Close'
    end

    within_testid('work-item-time-tracking') do
      expect(page).to have_text 'Spent 3d'
    end
  end
end

def add_comment(quick_action)
  fill_in 'Add a reply', with: "#{quick_action} "
  click_button 'Comment'
  expect(page).to have_field('Add a reply', with: '')
end
