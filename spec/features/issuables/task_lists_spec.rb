# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Task Lists', :js, feature_category: :markdown do
  include Warden::Test::Helpers

  let_it_be(:project) { create(:project, :public, :repository) }
  let_it_be(:user)    { create(:user, maintainer_of: project) }
  let_it_be(:user2)   { create(:user, guest_of: project) }

  let(:markdown) do
    <<-MARKDOWN.strip_heredoc
    This is a task list:

    - [ ] Incomplete entry 1
    - [x] Complete entry 1
    - [ ] Incomplete entry 2
    - [x] Complete entry 2
    - [ ] Incomplete entry 3
    - [ ] Incomplete entry 4
    MARKDOWN
  end

  let(:single_incomplete_markdown) do
    <<-MARKDOWN.strip_heredoc
    This is a task list:

    - [ ] Incomplete entry 1
    MARKDOWN
  end

  let(:single_complete_markdown) do
    <<-MARKDOWN.strip_heredoc
    This is a task list:

    - [x] Incomplete entry 1
    MARKDOWN
  end

  before do
    sign_in(user)
  end

  describe 'for Merge Requests' do
    def visit_merge_request(project, merge)
      visit project_merge_request_path(project, merge)
    end

    shared_examples 'multiple tasks' do
      it 'renders for description' do
        visit_merge_request(project, merge)
        wait_for_requests

        expect(page).to have_selector('ul.task-list',      count: 1)
        expect(page).to have_selector('li.task-list-item', count: 6)
        expect(page).to have_selector('ul input[checked]', count: 2)
      end

      it 'contains the required selectors' do
        visit_merge_request(project, merge)
        wait_for_requests

        container = '.detail-page-description .description.js-task-list-container'

        expect(page).to have_selector(container)
        expect(page).to have_selector("#{container} .md .task-list .task-list-item .task-list-item-checkbox")
        expect(page).to have_selector("#{container} .js-task-list-field", visible: :hidden)
        expect(page).to have_selector('form.js-issuable-update')
      end

      it 'is only editable by author' do
        visit_merge_request(project, merge)
        wait_for_requests

        expect(page).to have_selector('.js-task-list-container')
        expect(page).to have_selector('li.task-list-item.enabled', count: 6)

        logout(:user)
        sign_in(user2)
        visit current_path
        wait_for_requests

        expect(page).not_to have_selector('.js-task-list-container')
        expect(page).to have_selector('li.task-list-item.enabled', count: 0)
        expect(page).to have_selector('li.task-list-item input[disabled]', count: 6)
      end
    end

    context 'when merge request is open' do
      let!(:merge) { create(:merge_request, :simple, description: markdown, author: user, source_project: project) }

      it_behaves_like 'multiple tasks'

      it 'provides a summary on MergeRequests#index' do
        visit project_merge_requests_path(project)

        expect(page).to have_content("2 of 6 checklist items completed")
      end
    end

    context 'when merge request is closed' do
      let!(:merge) { create(:merge_request, :closed, :simple, description: markdown, author: user, source_project: project) }

      it_behaves_like 'multiple tasks'
    end

    describe 'single incomplete task' do
      let!(:merge) { create(:merge_request, :simple, description: single_incomplete_markdown, author: user, source_project: project) }

      it 'renders for description' do
        visit_merge_request(project, merge)
        wait_for_requests

        expect(page).to have_selector('ul.task-list',      count: 1)
        expect(page).to have_selector('li.task-list-item', count: 1)
        expect(page).to have_selector('ul input[checked]', count: 0)
      end

      it 'provides a summary on MergeRequests#index' do
        visit project_merge_requests_path(project)

        expect(page).to have_content("0 of 1 checklist item completed")
      end
    end

    describe 'single complete task' do
      let!(:merge) { create(:merge_request, :simple, description: single_complete_markdown, author: user, source_project: project) }

      it 'renders for description' do
        visit_merge_request(project, merge)
        wait_for_requests

        expect(page).to have_selector('ul.task-list',      count: 1)
        expect(page).to have_selector('li.task-list-item', count: 1)
        expect(page).to have_selector('ul input[checked]', count: 1)
      end

      it 'provides a summary on MergeRequests#index' do
        visit project_merge_requests_path(project)

        expect(page).to have_content("1 of 1 checklist item completed")
      end
    end
  end

  describe 'markdown task edge cases' do
    describe 'markdown starting with new line character' do
      let(:markdown_starting_with_new_line) do
        <<~MARKDOWN

        - [ ] Task 1
        MARKDOWN
      end

      let(:merge_request) { create(:merge_request, description: markdown_starting_with_new_line, author: user, source_project: project) }

      it 'allows the task to be checked' do
        visit project_merge_request_path(project, merge_request)
        wait_for_requests

        expect(page).to have_selector('ul input[checked]', count: 0)

        find('.task-list-item-checkbox').click
        wait_for_requests

        visit project_merge_request_path(project, merge_request)
        wait_for_requests

        expect(page).to have_selector('ul input[checked]', count: 1)
      end
    end
  end
end
