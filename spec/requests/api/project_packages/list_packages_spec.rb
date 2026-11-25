# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::ProjectPackages, feature_category: :package_registry do
  let_it_be_with_reload(:project) { create(:project, :public) }

  let_it_be(:user) { create(:user) }
  let!(:package1) { create(:npm_package, :last_downloaded_at, project: project, version: '3.1.0', name: "@#{project.root_namespace.path}/foo1") }
  let(:package_url) { "/projects/#{project.id}/packages/#{package1.id}" }
  let!(:package2) { create(:nuget_package, project: project, version: '2.0.4') }
  let!(:another_package) { create(:npm_package) }
  let(:params) { {} }

  describe 'GET /projects/:id/packages' do
    let(:url) { "/projects/#{project.id}/packages" }
    let(:package_schema) { 'public_api/v4/packages/packages' }

    subject(:request) { get api(url), params: params }

    it_behaves_like 'enforcing job token policies', :read_packages,
      allow_public_access_for_enabled_project_features: :package_registry do
      let(:params) { { job_token: target_job.token } }
    end

    it_behaves_like 'authorizing granular token permissions', :read_package do
      before_all { project.add_developer(user) }

      let(:boundary_object) { project }
      let(:request) { get api(url, personal_access_token: pat) }
    end

    context 'without the need for a license' do
      context 'project is public' do
        it_behaves_like 'returns packages', :project, :no_type
      end

      context 'with conan package' do
        let!(:conan_package) { create(:conan_package, project: project) }

        it 'uses the conan recipe as the package name' do
          subject

          response_conan_package = json_response.find { |package| package['id'] == conan_package.id }

          expect(response_conan_package['name']).to eq(conan_package.conan_recipe)
          expect(response_conan_package['conan_package_name']).to eq(conan_package.name)
        end
      end

      context 'with terraform module package' do
        let_it_be(:terraform_module_package) { create(:terraform_module_package, project: project) }

        context 'when no package_type filter is set' do
          let(:params) { {} }

          it 'filters out terraform module packages' do
            subject

            expect(json_response).not_to include(a_hash_including('package_type' => 'terraform_module'))
          end

          it 'returns packages with the package registry web_path' do
            subject

            expect(json_response).to include(a_hash_including('_links' => a_hash_including('web_path' => include('packages'))))
          end
        end

        context 'when package_type filter is set to terraform_module' do
          let(:params) { { package_type: :terraform_module } }

          it 'returns the terraform module package' do
            subject

            expect(json_response).to include(a_hash_including('package_type' => 'terraform_module'))
          end

          it 'returns the terraform module package with the terraform module registry web_path' do
            subject
            expect(json_response).to include(a_hash_including('_links' => a_hash_including('web_path' => include('terraform_module_registry'))))
          end
        end

        context 'in nested group' do
          let_it_be(:nested_project) { create(:project, :public, :in_subgroup) }
          let_it_be(:nested_terraform_module_package) { create(:terraform_module_package, project: nested_project) }

          let(:params) { { package_type: :terraform_module } }
          let(:url) { "/projects/#{nested_project.id}/packages" }

          it 'returns the nested terraform module package with the correct web_path' do
            subject

            expect(json_response).to include(a_hash_including('_links' => a_hash_including('web_path' => include(nested_project.namespace.full_path))))
          end
        end

        context 'with JOB-TOKEN auth' do
          let_it_be(:job) { create(:ci_build, :running, user: user, project: project) }

          subject { get api(url, job_token: job.token) }

          it_behaves_like 'returns packages', :project, :maintainer
          it_behaves_like 'returns packages', :project, :developer
          it_behaves_like 'returns packages', :project, :reporter
          it_behaves_like 'returns packages', :project, :no_type
          it_behaves_like 'returns packages', :project, :guest
        end
      end

      context 'project is private' do
        let_it_be_with_reload(:project) { create(:project, :private) }

        context 'for unauthenticated user' do
          it_behaves_like 'rejects packages access', :project, :no_type, :not_found
        end

        context 'for authenticated user' do
          subject { get api(url, user) }

          it_behaves_like 'returns packages', :project, :maintainer
          it_behaves_like 'returns packages', :project, :developer
          it_behaves_like 'returns packages', :project, :reporter
          it_behaves_like 'rejects packages access', :project, :no_type, :not_found
          it_behaves_like 'returns packages', :project, :guest

          context 'user is a maintainer' do
            before_all { project.add_maintainer(user) }

            it 'returns the destroy url' do
              subject

              expect(json_response.first['_links']).to include('delete_api_path')
            end
          end
        end

        context 'with JOB-TOKEN auth' do
          let_it_be(:job) { create(:ci_build, :running, user: user, project: project) }

          subject { get api(url, job_token: job.token) }

          it_behaves_like 'returns packages', :project, :maintainer
          it_behaves_like 'returns packages', :project, :developer
          it_behaves_like 'returns packages', :project, :reporter
          it_behaves_like 'rejects packages access', :project, :no_type, :forbidden
          # TODO uncomment when https://gitlab.com/gitlab-org/gitlab/-/issues/370998 is resolved
          # it_behaves_like 'rejects packages access', :project, :guest, :not_found
        end
      end

      context 'with pagination params' do
        let!(:package3) { create(:maven_package, project: project) }
        let!(:package4) { create(:maven_package, project: project) }

        context 'with pagination params' do
          let!(:package3) { create(:npm_package, project: project) }
          let!(:package4) { create(:npm_package, project: project) }

          it_behaves_like 'returns paginated packages'
        end
      end

      context 'with sorting' do
        let(:package3) { create(:maven_package, project: project, version: '1.1.1', name: 'zzz') }

        before do
          travel_to(1.day.ago) do
            package3
          end
        end

        it_behaves_like 'package sorting', 'name' do
          let(:packages) { [package1, package2, package3] }
        end

        it_behaves_like 'package sorting', 'created_at' do
          let(:packages) { [package3, package1, package2] }
        end

        it_behaves_like 'package sorting', 'version' do
          let(:packages) { [package3, package2, package1] }
        end

        it_behaves_like 'package sorting', 'type' do
          let(:packages) { [package3, package1, package2] }
        end
      end

      it_behaves_like 'filters on each package_type', is_project: true

      context 'filtering on package_name' do
        include_context 'package filter context'

        it 'returns the named package' do
          url = package_filter_url(:name, 'nuget')
          get api(url, user)

          expect(json_response.length).to eq(1)
          expect(json_response.first['name']).to include(package2.name)
        end
      end

      context 'filtering on package_version' do
        include_context 'package filter context'

        it 'returns the versioned package' do
          url = package_filter_url(:version, '2.0.4')
          get api(url, user)

          expect(json_response.length).to eq(1)
          expect(json_response.first['version']).to eq(package2.version)
        end

        it 'include_versionless has no effect' do
          url = "/projects/#{project.id}/packages?package_version=2.0.4&include_versionless=true"
          get api(url, user)

          expect(json_response.length).to eq(1)
          expect(json_response.first['version']).to eq(package2.version)
        end
      end

      it_behaves_like 'with versionless packages'
      it_behaves_like 'with status param'
      it_behaves_like 'does not cause n^2 queries'

      context 'with build info' do
        let_it_be(:package1) { create(:npm_package, :with_build, project: project) }
        let_it_be(:job) { create(:ci_build, :running, user: user, project: project) }

        before_all { project.add_reporter(user) }

        context 'when repository access is enabled' do
          context 'with user auth' do
            it 'includes pipeline information' do
              get api(package_url, user)

              expect(response).to have_gitlab_http_status(:ok)
              expect(response).to match_response_schema('public_api/v4/packages/package_with_build')
            end
          end

          context 'with job token auth' do
            it 'includes pipeline information' do
              get api(package_url, job_token: job.token)

              expect(response).to have_gitlab_http_status(:ok)
              expect(response).to match_response_schema('public_api/v4/packages/package_with_build')
            end
          end
        end

        context 'when repository access is disabled' do
          before_all do
            project.project_feature.update!(
              repository_access_level: ProjectFeature::DISABLED,
              merge_requests_access_level: ProjectFeature::DISABLED,
              builds_access_level: ProjectFeature::DISABLED
            )
          end

          context 'with user auth' do
            it 'does not include pipeline information' do
              get api(package_url, user)

              expect(response).to have_gitlab_http_status(:ok)
              expect(json_response).not_to include('pipeline', 'pipelines')
            end
          end

          context 'with job token auth' do
            it 'does not include pipeline information' do
              get api(package_url, job_token: job.token)

              expect(response).to have_gitlab_http_status(:ok)
              expect(json_response).not_to include('pipeline', 'pipelines')
            end
          end
        end
      end
    end
  end
end
