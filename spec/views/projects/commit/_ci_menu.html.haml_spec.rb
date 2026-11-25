# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'projects/commit/_ci_menu.html.haml', feature_category: :source_code_management do
  let_it_be(:project) { create(:project, :repository) } # rubocop:disable RSpec/FactoryBot/AvoidCreate -- needs a real repository for the commit

  let(:commit) { project.commit }

  before do
    assign(:project, project)
    assign(:commit, commit)
    allow(view).to receive(:current_user).and_return(nil)

    # rubocop:disable RSpec/FactoryBot/AvoidCreate -- the badge counts persisted pipelines
    create_list(:ci_pipeline, 2, project: project, sha: commit.sha)
    # rubocop:enable RSpec/FactoryBot/AvoidCreate
  end

  it 'shows the number of pipelines for the commit' do
    render

    expect(rendered).to have_css('.js-pipelines-mr-count', text: '2')
  end
end
