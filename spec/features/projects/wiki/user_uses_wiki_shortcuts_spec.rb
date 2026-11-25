# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Project wiki > User uses wiki shortcuts', feature_category: :wiki do
  let_it_be(:user) { create(:user) }

  let(:project) { create(:project, namespace: user.namespace, creator: user) }
  let(:wiki) { create(:project_wiki, user: user, project: project) }
  let(:wiki_page) { create(:wiki_page, wiki: wiki, title: 'home', content: 'Home page') }

  before do
    sign_in(user)
    visit wiki_page_path(wiki, wiki_page)
  end

  it 'visits edit wiki page using "e" keyboard shortcut', :js do
    find('body').native.send_key('e')

    expect(find('#wiki_title').value).to eq('home')
  end
end
