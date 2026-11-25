# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Projects::UsageQuotasController, feature_category: :consumables_cost_management do
  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, group: group) }

  describe 'GET #index' do
    subject(:request) { get project_usage_quotas_path(project) }

    before do
      sign_in(user)
    end

    context 'when user does not have read_usage_quotas permission' do
      before_all do
        project.add_developer(user)
      end

      it 'renders not_found' do
        request

        expect(response).to have_gitlab_http_status(:not_found)
        expect(response.body).to include(s_('404|404: Page not found'))
        expect(response.body).not_to have_css('.js-search-settings-app')
      end
    end

    context 'when user has read_usage_quotas permission' do
      before_all do
        project.add_maintainer(user)
      end

      it 'renders index with 200 status code' do
        request

        expect(response).to have_gitlab_http_status(:ok)
        expect(response.body).to have_css('#js-storage-usage-app')
        expect(response.body).not_to have_css('.js-search-settings-app')
      end
    end
  end
end
