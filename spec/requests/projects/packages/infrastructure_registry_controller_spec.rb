# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Projects::Packages::InfrastructureRegistryController, feature_category: :package_registry do
  let_it_be(:project) { create(:project, :private) }
  let_it_be(:user) { create(:user, maintainer_of: project) }

  before do
    sign_in(user)
  end

  describe 'GET /:namespace/:project/-/terraform_module_registry' do
    subject(:index_request) { get project_infrastructure_registry_index_path(project) }

    it 'returns ok' do
      index_request

      expect(response).to have_gitlab_http_status(:ok)
    end

    context 'when the packages registry is not available' do
      before do
        stub_config(packages: { enabled: false })
      end

      it 'returns not found' do
        index_request

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end
  end

  describe 'GET /:namespace/:project/-/terraform_module_registry/:id' do
    let_it_be(:pipeline) { create(:ci_pipeline, project: project, user: user) }
    let_it_be(:terraform_module) { create(:terraform_module_package, project: project, pipelines: [pipeline]) }

    subject(:show_request) do
      get project_infrastructure_registry_path(project, terraform_module.id)
    end

    it 'returns ok' do
      show_request

      expect(response).to have_gitlab_http_status(:ok)
    end

    context 'when the packages registry is not available' do
      before do
        stub_config(packages: { enabled: false })
      end

      it 'returns not found' do
        show_request

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    it 'preloads pipeline associations' do
      show_path = project_infrastructure_registry_path(project, terraform_module.id)

      get show_path

      control = ActiveRecord::QueryRecorder.new(skip_cached: false) { get show_path }

      create_list(:ci_pipeline, 2, project: project, user: user).each do |extra_pipeline|
        create(:package_build_info, package: terraform_module, pipeline: extra_pipeline)
      end

      expect { get show_path }.to issue_same_number_of_queries_as(control)
    end
  end
end
