# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'shared/milestones/_milestone.html.haml', feature_category: :team_planning do
  # rubocop:disable RSpec/FactoryBot/AvoidCreate -- Necessary to check authorization
  let_it_be(:group) { create(:group) }
  let_it_be_with_reload(:project) { create(:project, group: group) }
  let_it_be(:developer) { create(:user, developer_of: [group]) }
  let_it_be_with_reload(:milestone) { create(:milestone, project: project) }
  let_it_be_with_reload(:release) { create(:release, project: project, milestones: [milestone]) }
  let_it_be(:unauthorized_user) { create(:user) }
  # rubocop:enable RSpec/FactoryBot/AvoidCreate

  let(:current_user) { developer }

  describe 'release information' do
    before do
      render 'shared/milestones/milestone',
        issues_path: issues_group_path(group),
        merge_requests_path: merge_requests_group_path(group),
        milestone: milestone,
        current_user: current_user
    end

    it 'renders recent releases' do
      expect(rendered).to include(release.name)
    end

    context 'when user does not have access to the release' do
      let(:current_user) { unauthorized_user }

      it 'does not render release information' do
        expect(rendered).not_to include(release.name)
      end
    end
  end

  describe 'milestone actions' do
    let(:actions) { Nokogiri::HTML(rendered).at_css('.js-vue-milestone-actions') }

    before do
      assign(:project, project)
      allow(Ability).to receive(:allowed?).and_call_original
    end

    def render_milestone
      render 'shared/milestones/milestone',
        issues_path: issues_group_path(group),
        merge_requests_path: merge_requests_group_path(group),
        milestone: milestone,
        current_user: current_user
    end

    it 'shows edit, close and delete actions to a user who can update and delete the milestone' do
      render_milestone

      expect(actions['data-edit-url']).to be_present
      expect(actions['data-close-url']).to be_present
      expect(actions['data-show-delete']).to eq('true')
    end

    it 'hides edit and close actions without update_milestone' do
      allow(Ability).to receive(:allowed?).with(current_user, :update_milestone, milestone).and_return(false)

      render_milestone

      expect(actions['data-edit-url']).to be_empty
      expect(actions['data-close-url']).to be_empty
      expect(actions['data-show-delete']).to eq('true')
    end

    it 'hides the delete action without delete_milestone' do
      allow(Ability).to receive(:allowed?).with(current_user, :delete_milestone, milestone).and_return(false)

      render_milestone

      expect(actions['data-edit-url']).to be_present
      expect(actions['data-show-delete']).to eq('false')
    end
  end
end
