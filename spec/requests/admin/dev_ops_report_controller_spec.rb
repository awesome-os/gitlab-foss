# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Admin::DevOpsReportController, :enable_admin_mode, feature_category: :devops_reports do
  describe 'show_adoption?' do
    it 'is always false' do
      expect(described_class.new.show_adoption?).to be_falsey
    end
  end

  describe 'GET /admin/dev_ops_reports' do
    context 'as admin' do
      let(:user) { create(:admin) }

      before do
        sign_in(user)
      end

      it 'responds with success' do
        get admin_dev_ops_reports_path

        expect(response).to have_gitlab_http_status(:success)
      end

      it_behaves_like 'internal event tracking' do
        let(:event) { 'i_analytics_dev_ops_score' }
        let(:category) { described_class.name }

        subject { get admin_dev_ops_reports_path }
      end
    end

    context 'as normal user' do
      let(:user) { create(:user) }

      before do
        sign_in(user)
      end

      it 'responds with 404' do
        get admin_dev_ops_reports_path

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end
  end
end
