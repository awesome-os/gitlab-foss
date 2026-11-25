# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Dashboard::TodosController, feature_category: :notifications do
  let_it_be(:user) { create(:user) }

  before do
    sign_in(user)
  end

  describe 'GET /dashboard/todos' do
    it 'renders the index view' do
      get dashboard_todos_path

      expect(response).to have_gitlab_http_status(:ok)
      expect(response.body).to include(s_('Todos|Your To-Do List shows what to work on next'))
    end

    context 'with the review_decision_todo_actions feature flag' do
      it 'pushes the feature flag to the frontend' do
        get dashboard_todos_path

        expect(response.body).to have_pushed_frontend_feature_flags(reviewDecisionTodoActions: true)
      end

      it 'pushes the disabled feature flag to the frontend' do
        stub_feature_flags(review_decision_todo_actions: false)

        get dashboard_todos_path

        expect(response.body).to have_pushed_frontend_feature_flags(reviewDecisionTodoActions: false)
      end
    end

    context 'with external authorization' do
      subject { get dashboard_todos_path }

      it_behaves_like 'disabled when using an external authorization service'
    end

    it_behaves_like 'internal event tracking' do
      subject { get dashboard_todos_path }

      let(:event) { 'view_todo_list' }
      let(:category) { described_class.name }
      let(:user) { create(:user) }
    end
  end
end
