# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'projects/branch_defaults/_show.html.haml', feature_category: :source_code_management do
  before do
    assign(:project, project)
  end

  context 'when issues are enabled' do
    let(:branch_name_template) { 'feature-%{id}' }
    let(:project) { build(:project, issue_branch_template: branch_name_template) }

    it 'renders the branch name template field with the saved template', :aggregate_failures do
      render

      expect(rendered).to have_text('Branch name template')
      expect(rendered).to have_field('project[issue_branch_template]', with: branch_name_template)
    end
  end

  context 'when issues are disabled' do
    let(:project) { build(:project, :issues_disabled) }

    it 'does not render the branch name template field', :aggregate_failures do
      render

      expect(rendered).to have_no_text('Branch name template')
      expect(rendered).to have_no_field('project[issue_branch_template]')
    end
  end
end
