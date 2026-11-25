# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::ProjectPackages, feature_category: :package_registry do
  using RSpec::Parameterized::TableSyntax

  let_it_be_with_reload(:project) { create(:project, :public) }

  let_it_be(:user) { create(:user) }
  let!(:package1) { create(:npm_package, :last_downloaded_at, project: project, version: '3.1.0', name: "@#{project.root_namespace.path}/foo1") }
  let(:package_url) { "/projects/#{project.id}/packages/#{package1.id}" }
  let!(:package2) { create(:nuget_package, project: project, version: '2.0.4') }
  let!(:another_package) { create(:npm_package) }
  let(:no_package_url) { "/projects/#{project.id}/packages/0" }
  let(:wrong_package_url) { "/projects/#{project.id}/packages/#{another_package.id}" }

  describe 'DELETE /projects/:id/packages/:package_id' do
    it_behaves_like 'enforcing job token policies', :admin_packages do
      before_all do
        project.add_maintainer(user)
      end

      let(:request) { delete api(package_url), params: { job_token: target_job.token } }
    end

    it_behaves_like 'authorizing granular token permissions', :delete_package do
      before_all { project.add_maintainer(user) }

      let(:boundary_object) { project }
      let(:request) { delete api(package_url, personal_access_token: pat) }
    end

    context 'without the need for a license' do
      context 'when project is public' do
        it 'returns 403 for non authenticated user' do
          expect { delete api(package_url) }.not_to change { ::Packages::Package.pending_destruction.count }

          expect(response).to have_gitlab_http_status(:forbidden)
        end

        it 'returns 403 for a user without access to the project' do
          expect { delete api(package_url, user) }.not_to change { ::Packages::Package.pending_destruction.count }

          expect(response).to have_gitlab_http_status(:forbidden)
        end
      end

      context 'when project is private' do
        let_it_be_with_reload(:project) { create(:project, :private) }

        before do
          expect(::Packages::Maven::Metadata::SyncWorker).not_to receive(:perform_async)
        end

        it 'returns 404 for non authenticated user' do
          expect { delete api(package_url) }.not_to change { ::Packages::Package.pending_destruction.count }

          expect(response).to have_gitlab_http_status(:not_found)
        end

        it 'returns 404 for a user without access to the project' do
          expect { delete api(package_url, user) }.not_to change { ::Packages::Package.pending_destruction.count }

          expect(response).to have_gitlab_http_status(:not_found)
        end

        it 'returns 404 when the package does not exist' do
          project.add_maintainer(user)

          expect { delete api(no_package_url, user) }.not_to change { ::Packages::Package.pending_destruction.count }

          expect(response).to have_gitlab_http_status(:not_found)
        end

        it 'returns 404 for the package from a different project' do
          project.add_maintainer(user)

          expect { delete api(wrong_package_url, user) }.not_to change { ::Packages::Package.pending_destruction.count }

          expect(response).to have_gitlab_http_status(:not_found)
        end

        it 'returns 403 for a user without enough permissions' do
          project.add_developer(user)

          expect { delete api(package_url, user) }.not_to change { ::Packages::Package.pending_destruction.count }

          expect(response).to have_gitlab_http_status(:forbidden)
        end

        it 'returns 204' do
          project.add_maintainer(user)

          expect { delete api(package_url, user) }.to change { ::Packages::Package.pending_destruction.count }.by(1)

          expect(response).to have_gitlab_http_status(:no_content)
        end

        it_behaves_like 'enqueue a worker to sync a npm metadata cache' do
          let(:package_name) { package1.name }

          subject { delete api(package_url, user) }
        end

        context 'with JOB-TOKEN auth' do
          let_it_be(:job) { create(:ci_build, :running, user: user, project: project) }

          it 'returns 403 for a user without enough permissions' do
            project.add_developer(user)

            expect { delete api(package_url, job_token: job.token) }.not_to change { ::Packages::Package.pending_destruction.count }

            expect(response).to have_gitlab_http_status(:forbidden)
          end

          it 'returns 204' do
            project.add_maintainer(user)

            expect { delete api(package_url, job_token: job.token) }.to change { ::Packages::Package.pending_destruction.count }.by(1)

            expect(response).to have_gitlab_http_status(:no_content)
          end
        end

        context 'with package protection rule for different roles and package_name_patterns', :enable_admin_mode do
          let_it_be(:pat_project_maintainer) { create(:personal_access_token, user: create(:user, maintainer_of: [project])) }
          let_it_be(:pat_project_owner) { create(:personal_access_token, user: create(:user, owner_of: [project])) }
          let_it_be(:pat_instance_admin) { create(:personal_access_token, :admin_mode, user: create(:admin)) }
          let_it_be(:headers_pat_project_maintainer) { { Gitlab::Auth::AuthFinders::PRIVATE_TOKEN_HEADER => pat_project_maintainer.token } }
          let_it_be(:headers_pat_project_owner) { { Gitlab::Auth::AuthFinders::PRIVATE_TOKEN_HEADER => pat_project_owner.token } }
          let_it_be(:headers_pat_instance_admin) { { Gitlab::Auth::AuthFinders::PRIVATE_TOKEN_HEADER => pat_instance_admin.token } }
          let_it_be(:job_from_project_maintainer) { create(:ci_build, :running, user: pat_project_maintainer.user, project: project) }
          let_it_be(:job_from_project_owner) { create(:ci_build, :running, user: pat_project_owner.user, project: project) }

          let_it_be(:headers_job_token_from_maintainer) { { Gitlab::Auth::AuthFinders::JOB_TOKEN_HEADER => job_from_project_maintainer.token } }
          let_it_be(:headers_job_token_from_owner) { { Gitlab::Auth::AuthFinders::JOB_TOKEN_HEADER => job_from_project_owner.token } }

          let(:package_protection_rule) { create(:package_protection_rule, project: project) }

          let(:package_name) { package1.name }
          let(:package_name_no_match) { "#{package_name}_no_match" }

          subject do
            delete api(package_url), headers: headers
            response
          end

          shared_examples 'deleting package protected' do
            it_behaves_like 'returning response status with message',
              status: :forbidden,
              message: 'Package is deletion protected.'

            it { expect { subject }.not_to change { ::Packages::Package.pending_destruction.count } }

            context 'when feature flag :packages_protected_packages_delete disabled' do
              before do
                stub_feature_flags(packages_protected_packages_delete: false)
              end

              it_behaves_like 'deleting package'
            end
          end

          shared_examples 'deleting package' do
            it_behaves_like 'returning response status', :no_content
            it { expect { subject }.to change { ::Packages::Package.pending_destruction.count }.by(1) }
          end

          where(:package_name_pattern, :minimum_access_level_for_delete, :headers, :shared_examples_name) do
            ref(:package_name)          | :owner | ref(:headers_job_token_from_maintainer) | 'deleting package protected'
            ref(:package_name)          | :owner | ref(:headers_job_token_from_owner)      | 'deleting package'
            ref(:package_name)          | :owner | ref(:headers_pat_project_maintainer)    | 'deleting package protected'
            ref(:package_name)          | :owner | ref(:headers_pat_project_owner)         | 'deleting package'
            ref(:package_name)          | :owner | ref(:headers_pat_instance_admin)        | 'deleting package'

            ref(:package_name)          | :admin | ref(:headers_job_token_from_owner)      | 'deleting package protected'
            ref(:package_name)          | :admin | ref(:headers_pat_project_maintainer)    | 'deleting package protected'
            ref(:package_name)          | :admin | ref(:headers_pat_project_owner)         | 'deleting package protected'
            ref(:package_name)          | :admin | ref(:headers_pat_instance_admin)        | 'deleting package'

            ref(:package_name_no_match) | :owner | ref(:headers_pat_project_owner)         | 'deleting package'
          end

          with_them do
            before do
              package_protection_rule.update!(
                package_name_pattern: package_name_pattern,
                package_type: package1.package_type,
                minimum_access_level_for_delete: minimum_access_level_for_delete
              )
            end

            it_behaves_like params[:shared_examples_name]
          end

          context 'for package with unsupported package type for package protection rule' do
            let_it_be(:rubygems_package) { create(:rubygems_package, project:) }

            let(:headers) { headers_pat_project_maintainer }

            subject do
              delete api("/projects/#{project.id}/packages/#{rubygems_package.id}"), headers: headers
              response
            end

            it_behaves_like 'deleting package'
          end
        end
      end

      context 'with a maven package' do
        let_it_be(:package1) { create(:maven_package, project: project) }

        it 'enqueues a sync worker job' do
          project.add_maintainer(user)

          expect(::Packages::Maven::Metadata::SyncWorker)
            .to receive(:perform_async).with(user.id, project.id, package1.name)

          delete api(package_url, user)
        end

        it_behaves_like 'does not enqueue a worker to sync a npm metadata cache' do
          before_all { project.add_maintainer(user) }

          subject { delete api(package_url, user) }
        end

        it_behaves_like 'does not enqueue a worker to sync a helm metadata cache' do
          before_all { project.add_maintainer(user) }

          subject(:execute) { delete api(package_url, user) }
        end
      end

      context 'with a helm package' do
        let_it_be(:package1) { create(:helm_package, project: project) }
        let_it_be(:channel) { 'stable' }
        let_it_be(:package_file) { create(:helm_package_file, package: package1, channel: channel) }

        it_behaves_like 'enqueue a worker to sync a helm metadata cache' do
          subject(:execute) { delete api(package_url, user) }

          let(:metadata) { package1.package_files.map(&:helm_file_metadatum) }
        end
      end
    end
  end
end
