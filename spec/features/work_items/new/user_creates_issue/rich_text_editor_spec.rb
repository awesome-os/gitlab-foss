# frozen_string_literal: true

require 'spec_helper'

RSpec.describe "User creates issue", :js, feature_category: :team_planning do
  include RichTextEditorHelpers

  let_it_be(:user, freeze: false) { create(:user) }

  context 'when signed in as a maintainer' do
    let_it_be(:project, freeze: false) { create(:project) }

    before_all do
      project.add_maintainer(user)
    end

    before do
      sign_in(user)
      visit(new_project_issue_path(project))
    end

    it 'creates an issue with a description written in the rich text editor', feature_category: :markdown do
      fill_in 'Title', with: 'Rich text issue'
      switch_to_content_editor
      type_in_content_editor '**bold** text'
      wait_until_hidden_field_is_updated(/\*\*bold\*\* text/)
      click_button 'Create issue'

      within_testid('work-item-description') do
        expect(page).to have_css('strong', text: 'bold')
      end
    end

    describe 'rich text editor image resizing', feature_category: :markdown do
      it 'renders correctly with an image as initial content after image is resized' do
        page.driver.browser.manage.window.resize_to(1280, 720)
        click_attachment_button

        switch_to_content_editor
        display_media_bubble_menu '[data-testid="content_editor_editablebox"] img[src]', 'big-image.png'

        within content_editor_testid do
          drag_element(find_by_testid('image-resize-se'), -200, -200)
        end

        wait_until_hidden_field_is_updated(/width=/)
        switch_to_markdown_editor

        textarea_value = page.find('textarea').value

        expect(textarea_value).to start_with('![big-image.png](/uploads/')

        # Actual image resolution is 6000x4000 and it gets resized to 700x466 on upload
        expect(textarea_value).to end_with('/big-image.png){width=700 height=466}')
      end
    end

    describe 'rich text editor quick action suggestions', feature_category: :markdown do
      let(:suggestions_dropdown) { '[data-testid="content-editor-suggestions-dropdown"]' }

      before do
        create(:label, project: project, title: 'My Cool Label')
        create(:milestone, project: project, title: 'My Cool Milestone')

        switch_to_content_editor
      end

      it 'scrolls selected item into view when navigating with keyboard' do
        type_in_content_editor '/'

        expect(find(suggestions_dropdown)).to have_text('label')

        expect(dropdown_scroll_top).to be 0

        send_keys :arrow_up

        expect(dropdown_scroll_top).to be > 100
      end

      def dropdown_scroll_top
        evaluate_script("document.querySelector('#{suggestions_dropdown}').scrollTop")
      end
    end

    describe 'rich text editor placeholders', feature_category: :markdown do
      let(:placeholder_selector) { '[data-testid="content-editor-placeholder"]' }

      before do
        find('textarea').set('Server: %{gitlab_server}')
        switch_to_content_editor
      end

      it 'displays the placeholder syntax in a tooltip on hover' do
        page.within content_editor_testid do
          find(placeholder_selector, text: Gitlab.config.gitlab.host).hover
        end

        expect(page).to have_css('[role="tooltip"]', text: '%{gitlab_server}')
      end

      it 'displays the placeholder syntax in a tooltip only while the placeholder is selected' do
        page.within content_editor_testid do
          find(placeholder_selector).click
        end

        find_button('Switch to plain text editing').hover
        type_in_content_editor :right

        expect(page).to have_no_css('[role="tooltip"]', text: '%{gitlab_server}')

        type_in_content_editor :left

        expect(page).to have_css('[role="tooltip"]', text: '%{gitlab_server}')
      end
    end
  end
end
