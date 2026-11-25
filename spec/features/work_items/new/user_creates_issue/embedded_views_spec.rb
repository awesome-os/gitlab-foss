# frozen_string_literal: true

require 'spec_helper'

RSpec.describe "User creates issue", :js, feature_category: :team_planning do
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

    it_behaves_like 'embedded views (GLQL)'
  end
end
