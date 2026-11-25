# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Profiles::SlacksController, feature_category: :integrations do
  let_it_be(:user) { create(:user) }

  before do
    sign_in(user)

    allow(subject).to receive(:current_user).and_return(user)
  end

  describe 'GET edit' do
    context 'when signed out' do
      before do
        sign_out(user)
        allow(subject).to receive(:current_user).and_return(nil)

        get :edit
      end

      it 'renders without projects, for the sign-in prompt' do
        expect(response).to render_template :edit
        expect(assigns[:projects]).to be_nil
      end
    end

    context 'without projects' do
      before do
        get :edit
      end

      it 'renders' do
        expect(response).to render_template :edit
      end

      it 'assigns projects' do
        expect(assigns[:projects]).to eq []
      end

      it 'assigns disabled_projects' do
        expect(assigns[:disabled_projects]).to eq []
      end
    end

    context 'when the user maintains more projects than the page offers' do
      let_it_be(:oldest_project) { create(:project, name: '0-oldest', maintainers: user) }
      let_it_be(:project_b) { create(:project, name: 'b-project', maintainers: user) }
      let_it_be(:project_a2) { create(:project, name: 'A-project', maintainers: user) }
      let_it_be(:project_a1) { create(:project, name: 'a-project', maintainers: user) }
      let_it_be(:installed_project) { create(:project, name: '0-installed', maintainers: user) }

      before_all do
        create(:gitlab_slack_application_integration, project: installed_project)
      end

      before do
        stub_const("#{described_class}::MAX_INSTALLABLE_PROJECTS", 3)

        get :edit
      end

      it 'offers the newest MAX_INSTALLABLE_PROJECTS projects without the app, by name and then id' do
        expect(assigns[:projects]).to eq([project_a2, project_a1, project_b])
      end
    end
  end

  describe 'GET slack_link' do
    let_it_be(:project) { create(:project) }

    context 'when user is not a maintainer of the project' do
      before do
        project.add_developer(user)
      end

      it 'renders 404' do
        get :slack_link, params: { project_id: project.id }

        expect(response).to have_gitlab_http_status(:not_found)
        expect(response.body).to be_blank
      end
    end

    context 'when user is a maintainer of the project' do
      before do
        project.add_maintainer(user)
      end

      it 'renders slack link' do
        allow(controller).to receive(:add_to_slack_link).and_return('mock_redirect_link')

        get :slack_link, params: { project_id: project.id }

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response).to eq({ 'add_to_slack_link' => 'mock_redirect_link' })
      end
    end

    context 'with a group' do
      let_it_be(:group) { create(:group) }

      it 'renders 404' do
        get :slack_link, params: { group_id: group.id }

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end
  end
end
