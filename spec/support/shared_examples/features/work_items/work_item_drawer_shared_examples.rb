# frozen_string_literal: true

RSpec.shared_examples 'when accessing the work item drawer' do
  it 'shows drawer when clicking issue' do
    expect(page).to have_selector('[data-testid="work-item-detail-panel"]')
  end

  it 'focus on first element of the drawer when clicking issue' do
    expect(page).to have_selector('[data-testid="work-item-detail-panel-ref-link"]', focused: true)
  end

  it 'shows issue details when drawer is open', :aggregate_failures do
    within_testid('work-item-detail-panel') do
      expect(page).to have_content(issue.title)
    end
  end

  context 'when clicking close button' do
    before do
      close_drawer
    end

    it 'unhighlights the active issue card' do
      expect(first_card[:class]).not_to include('is-active')
      expect(first_card[:class]).not_to include('multi-select')
    end

    it 'closes drawer when clicking close button' do
      expect(page).not_to have_selector('[data-testid="work-item-detail-panel"]')
    end
  end
end

RSpec.shared_examples 'work item drawer on the list page' do
  include_examples 'when accessing the work item drawer'

  it 'closes drawer when clicking issue' do
    expect(page).to have_selector('[data-testid="work-item-detail-panel"]')

    page.execute_script("arguments[0].click();", first_card.native)

    expect(page).not_to have_selector('[data-testid="work-item-detail-panel"]')
  end

  it 'updates title of a work item on the list', :aggregate_failures do
    within_testid('work-item-detail-panel') do
      find_by_testid('work-item-edit-form-button').click
      wait_for_requests
      find_by_testid('work-item-title-input').set('Test title')
      click_button 'Save changes'
      wait_for_requests

      close_drawer
    end

    expect(first_card).to have_content('Test title')
  end

  it 'updates the assigned user of a work item on the list', :aggregate_failures do
    within_testid('work-item-detail-panel') do
      within_testid('work-item-assignees') do
        click_button 'Edit'
        select_listbox_item(user.username)
        send_keys :escape
      end
    end

    expect(page).to have_link(user.name, href: user_path(user))
  end

  it 'make work item confidential on the list', :aggregate_failures do
    within_testid('work-item-detail-panel') do
      find_by_testid('work-item-actions-dropdown').click
      expect(page).not_to have_content('Confidential')
      find_by_testid('confidentiality-toggle-action').click
      wait_for_requests

      close_drawer
    end

    expect(first_card).to have_selector("button[data-testid='confidential-icon-container']")
  end

  it 'updates a label of a work item on the list', :aggregate_failures do
    within_testid('work-item-detail-panel') do
      within_testid 'work-item-labels' do
        expect(page).not_to have_css '.gl-label', text: label.title

        click_button 'Edit'
        select_listbox_item(label.title)
        click_button 'Apply'
      end

      close_drawer
    end

    expect(first_card).to have_link(label.name)
  end

  it 'updates milestone of a work item on the list', :aggregate_failures do
    within_testid('work-item-detail-panel') do
      within_testid 'work-item-milestone' do
        expect(page).not_to have_link(milestone.title)

        click_button 'Edit'
        send_keys "\"#{milestone.title}\""
        select_listbox_item(milestone.title)
      end

      close_drawer
    end

    expect(first_card).to have_link(milestone.title)
  end

  it 'updates comment count when user adds comments from the drawer', :aggregate_failures do
    expect(first_card).not_to have_selector('[data-testid="issuable-comments"]')

    within_testid('work-item-detail-panel') do
      fill_in 'Add a reply', with: 'Test comment from drawer'
      click_button 'Comment'
      wait_for_requests

      close_drawer
    end

    page.refresh

    within_testid 'issuable-comments' do
      expect(page).to have_content('1')
    end
  end
end
