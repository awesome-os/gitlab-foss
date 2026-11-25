# frozen_string_literal: true

require 'spec_helper'

# rubocop:disable RSpec/SpecFilePathFormat -- one file per badges endpoint, split from badges_spec.rb to keep CI jobs short
RSpec.describe API::Badges, feature_category: :groups_and_projects do
  include_context 'with API badges setup'

  let(:example_url2) { 'http://www.example1.com' }
  let(:example_url) { 'http://www.example.com' }

  describe 'CI_JOB_TOKEN authentication' do
    let(:user) { maintainer }
    let(:job) { create(:ci_build, :running, project: project, user: maintainer) }

    describe 'GET /projects/:id/badges' do
      it 'returns 200' do
        get api("/projects/#{project.id}/badges"), params: { job_token: job.token }

        expect(response).to have_gitlab_http_status(:ok)
      end

      it_behaves_like 'enforcing job token policies', :read_badges,
        allow_public_access_for_enabled_project_features: [:repository] do
        let(:request) do
          get api("/projects/#{source_project.id}/badges"), params: { job_token: target_job.token }
        end
      end
    end

    describe 'GET /projects/:id/badges/:badge_id' do
      it 'returns 200' do
        badge = project.project_badges.first

        get api("/projects/#{project.id}/badges/#{badge.id}"), params: { job_token: job.token }

        expect(response).to have_gitlab_http_status(:ok)
      end

      it_behaves_like 'enforcing job token policies', :read_badges,
        allow_public_access_for_enabled_project_features: [:repository] do
        let(:request) do
          badge = source_project.project_badges.first
          get api("/projects/#{source_project.id}/badges/#{badge.id}"), params: { job_token: target_job.token }
        end
      end
    end

    describe 'GET /projects/:id/badges/render' do
      it 'returns 200' do
        get api("/projects/#{project.id}/badges/render"),
          params: { link_url: example_url, image_url: example_url2, job_token: job.token }

        expect(response).to have_gitlab_http_status(:ok)
      end

      it_behaves_like 'enforcing job token policies', :admin_badges do
        let(:request) do
          get api("/projects/#{source_project.id}/badges/render"),
            params: { link_url: example_url, image_url: example_url2, job_token: target_job.token }
        end
      end
    end

    describe 'POST /projects/:id/badges' do
      it 'creates a badge', :aggregate_failures do
        expect do
          post api("/projects/#{project.id}/badges"),
            params: { link_url: example_url, image_url: example_url2, job_token: job.token }
        end.to change { project.project_badges.count }.by(1)

        expect(response).to have_gitlab_http_status(:created)
      end

      it_behaves_like 'enforcing job token policies', :admin_badges, expected_success_status: :created do
        let(:request) do
          post api("/projects/#{source_project.id}/badges"),
            params: { link_url: example_url, image_url: example_url2, job_token: target_job.token }
        end
      end
    end

    describe 'PUT /projects/:id/badges/:badge_id' do
      it 'updates a badge', :aggregate_failures do
        badge = project.project_badges.first

        put api("/projects/#{project.id}/badges/#{badge.id}"),
          params: { name: 'updated-name', job_token: job.token }

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response['name']).to eq('updated-name')
      end

      it_behaves_like 'enforcing job token policies', :admin_badges do
        let(:request) do
          badge = source_project.project_badges.first
          put api("/projects/#{source_project.id}/badges/#{badge.id}"),
            params: { name: 'updated-name', job_token: target_job.token }
        end
      end
    end

    describe 'DELETE /projects/:id/badges/:badge_id' do
      it 'deletes a badge', :aggregate_failures do
        badge = project.project_badges.first

        expect do
          delete api("/projects/#{project.id}/badges/#{badge.id}"),
            params: { job_token: job.token }
        end.to change { project.project_badges.count }.by(-1)

        expect(response).to have_gitlab_http_status(:no_content)
      end

      it_behaves_like 'enforcing job token policies', :admin_badges, expected_success_status: :no_content do
        let(:request) do
          badge = source_project.project_badges.first
          delete api("/projects/#{source_project.id}/badges/#{badge.id}"),
            params: { job_token: target_job.token }
        end
      end
    end
  end

  describe 'CI_JOB_TOKEN authentication for group badges' do
    let(:job) { create(:ci_build, :running, project: project, user: maintainer) }

    it 'does not grant access to GET /groups/:id/badges beyond public visibility' do
      private_group = create(:group, :private)

      get api("/groups/#{private_group.id}/badges"), params: { job_token: job.token }

      expect(response).to have_gitlab_http_status(:not_found)
    end

    it 'does not allow POST /groups/:id/badges' do
      post api("/groups/#{group.id}/badges"),
        params: { link_url: example_url, image_url: example_url2, job_token: job.token }

      expect(response).to have_gitlab_http_status(:unauthorized)
    end

    it 'does not allow PUT /groups/:id/badges/:badge_id' do
      badge = group.badges.first

      put api("/groups/#{group.id}/badges/#{badge.id}"),
        params: { name: 'updated-name', job_token: job.token }

      expect(response).to have_gitlab_http_status(:unauthorized)
    end

    it 'does not allow DELETE /groups/:id/badges/:badge_id' do
      badge = group.badges.first

      delete api("/groups/#{group.id}/badges/#{badge.id}"), params: { job_token: job.token }

      expect(response).to have_gitlab_http_status(:unauthorized)
    end
  end
end
# rubocop:enable RSpec/SpecFilePathFormat
