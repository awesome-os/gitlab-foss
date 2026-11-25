# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Project wiki > User views wiki templates', feature_category: :wiki do
  include WikiHelpers

  let_it_be(:user) { create(:user) }

  let(:wiki) { create(:project_wiki, user: user, project: project) }
  let(:project) { create(:project, namespace: user.namespace, creator: user) }

  let!(:wiki_template1) do
    create(:wiki_page, wiki: wiki, title: 'templates/template 3', content: '3')
  end

  let!(:wiki_template2) do
    create(:wiki_page, wiki: wiki, title: 'templates/template 1', content: '1')
  end

  let!(:wiki_template3) do
    create(:wiki_page, wiki: wiki, title: 'templates/template 2', content: '2')
  end

  let(:templates_li) do
    page.find('.wiki-pages-list').all('li')
  end

  let(:templates) do
    templates_li.map { |li| find_by_testid('wiki-page-link', context: li) }
  end

  before do
    sign_in(user)
    visit(wiki_path(wiki, action: :templates))
  end

  it 'shows a link to create a new template' do
    expect(page).to have_link('New template')
  end

  it 'shows an edit button to each template listed' do
    expect(templates_li).to all have_link(title: 'Edit template')
  end

  context 'when ordered by title' do
    let(:pages_ordered_by_title) { [wiki_template2, wiki_template3, wiki_template1] }

    context 'when asc' do
      it 'templates are displayed in direct order' do
        templates.each.with_index do |page_title, index|
          expect(page_title.text).to eq(pages_ordered_by_title[index].title)
        end
      end
    end

    context 'when desc' do
      before do
        page.within('.wiki-sort-dropdown') do
          page.find('.rspec-reverse-sort').click
        end
      end

      it 'templates are displayed in reversed order' do
        templates.reverse_each.with_index do |page_title, index|
          expect(page_title.text).to eq(pages_ordered_by_title[index].title)
        end
      end
    end
  end

  context 'when listing more templates than allowed items per page' do
    let(:items_per_page) { 1 }

    before do
      allow(Kaminari.config).to receive(:default_per_page).and_return(items_per_page)

      visit(wiki_path(wiki, action: :templates))
    end

    it 'shows pagination controls' do
      page.within('.gl-pagination') do
        expect(page).to have_testid('kaminari-pagination-prev')
        expect(page).to have_link("1")
        expect(page).to have_link("2")
        expect(page).to have_link("3")
        expect(page).to have_testid('kaminari-pagination-next')
      end
    end
  end
end
