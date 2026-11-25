# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Projects::BranchesController, feature_category: :source_code_management do
  let_it_be(:project) { create(:project, :small_repo) }
  let_it_be(:user) { create(:user, developer_of: project) }

  before do
    sign_in(user)
  end

  describe 'GET #new' do
    it 'renders the breadcrumbs' do
      get new_project_branch_path(project)

      breadcrumbs_json = Nokogiri::HTML(response.body)
        .at_css('#js-vue-page-breadcrumbs')['data-breadcrumbs-json']

      expect(Gitlab::Json::SafeParser.parse(breadcrumbs_json)).to match([
        a_hash_including('text' => project.creator.name, 'href' => user_path(project.creator)),
        a_hash_including('text' => project.name, 'href' => project_path(project)),
        a_hash_including('text' => 'Branches', 'href' => project_branches_path(project)),
        a_hash_including('text' => 'New branch', 'href' => new_project_branch_path(project))
      ])
    end
  end
end
