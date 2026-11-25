# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::ProjectPackages, feature_category: :package_registry do
  let_it_be_with_reload(:project) { create(:project, :public) }

  let_it_be(:user) { create(:user) }
  let!(:package1) { create(:npm_package, :last_downloaded_at, project: project, version: '3.1.0', name: "@#{project.root_namespace.path}/foo1") }
  let(:package_url) { "/projects/#{project.id}/packages/#{package1.id}" }
  let!(:package2) { create(:nuget_package, project: project, version: '2.0.4') }
  let!(:another_package) { create(:npm_package) }
  let(:no_package_url) { "/projects/#{project.id}/packages/0" }
  let(:wrong_package_url) { "/projects/#{project.id}/packages/#{another_package.id}" }

  describe 'GET /projects/:id/packages/:package_id' do
    let(:single_package_schema) { 'public_api/v4/packages/package' }

    subject { get api(package_url, user) }

    it_behaves_like 'enforcing job token policies', :read_packages,
      allow_public_access_for_enabled_project_features: :package_registry do
      let(:request) { get api(package_url), params: { job_token: target_job.token } }
    end

    it_behaves_like 'authorizing granular token permissions', :read_package do
      before_all { project.add_developer(user) }

      let(:boundary_object) { project }
      let(:request) { get api(package_url, personal_access_token: pat) }
    end

    shared_examples 'no destroy url' do
      it 'returns no destroy url' do
        subject

        expect(json_response['_links']).not_to include('delete_api_path')
      end
    end

    shared_examples 'destroy url' do
      it 'returns destroy url' do
        subject

        expect(json_response['_links']['delete_api_path']).to be_present
      end
    end

    context 'without the need for a license' do
      context 'without build info' do
        it 'does not include the pipeline attributes' do
          subject

          expect(json_response).not_to include('pipeline', 'pipelines')
        end
      end

      context 'with creator_id' do
        let_it_be(:creator) { create(:user) }
        let_it_be(:package_with_creator) { create(:npm_package, project: project, creator: creator) }
        let(:package_url) { "/projects/#{project.id}/packages/#{package_with_creator.id}" }

        it 'includes creator_id' do
          get api(package_url, user)

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response['creator_id']).to eq(creator.id)
        end
      end

      context 'without creator' do
        let_it_be(:package_without_creator) { create(:npm_package, project: project, creator: nil) }
        let(:package_url) { "/projects/#{project.id}/packages/#{package_without_creator.id}" }

        it 'returns null creator_id when creator is nil' do
          get api(package_url, user)

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response['creator_id']).to be_nil
        end
      end

      context 'with build info' do
        let_it_be(:package1) { create(:npm_package, :with_build, project: project) }
        let_it_be(:job) { create(:ci_build, :running, user: user, project: project) }

        before_all { project.add_reporter(user) }

        it 'returns an empty array for the pipelines attribute' do
          subject

          expect(json_response['pipelines']).to be_empty
        end

        context 'when repository access is enabled' do
          context 'with user auth' do
            it 'includes pipeline information' do
              subject

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
              subject

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

      context 'when project is public' do
        it 'returns 200 and the package information' do
          subject

          expect(response).to have_gitlab_http_status(:ok)
          expect(response).to match_response_schema(single_package_schema)
        end

        it 'returns 404 when the package does not exist' do
          get api(no_package_url, user)

          expect(response).to have_gitlab_http_status(:not_found)
        end

        it 'returns 404 for the package from a different project' do
          get api(wrong_package_url, user)

          expect(response).to have_gitlab_http_status(:not_found)
        end

        it_behaves_like 'no destroy url'

        context 'with JOB-TOKEN auth' do
          let_it_be(:job) { create(:ci_build, :running, user: user, project: project) }

          subject { get api(package_url, job_token: job.token) }

          it_behaves_like 'returns package', :project, :maintainer
          it_behaves_like 'returns package', :project, :developer
          it_behaves_like 'returns package', :project, :reporter
          it_behaves_like 'returns package', :project, :no_type
          it_behaves_like 'returns package', :project, :guest
        end

        context 'with a package without last_downloaded_at' do
          let(:package_url) { "/projects/#{project.id}/packages/#{package2.id}" }

          it 'returns 200 and the package information' do
            subject

            expect(response).to have_gitlab_http_status(:ok)
            expect(response).to match_response_schema(single_package_schema)
          end
        end
      end

      context 'when project is private' do
        let_it_be_with_reload(:project) { create(:project, :private) }

        it 'returns 404 for non authenticated user' do
          get api(package_url)

          expect(response).to have_gitlab_http_status(:not_found)
        end

        it 'returns 404 for a user without access to the project' do
          subject

          expect(response).to have_gitlab_http_status(:not_found)
        end

        context 'when user is a developer' do
          before_all { project.add_developer(user) }

          it 'returns 200 and the package information' do
            subject

            expect(response).to have_gitlab_http_status(:ok)
            expect(response).to match_response_schema(single_package_schema)
          end

          it_behaves_like 'no destroy url'
        end

        context 'when user is a maintainer' do
          before_all { project.add_maintainer(user) }

          it_behaves_like 'destroy url'
        end

        context 'with JOB-TOKEN auth' do
          let_it_be(:job) { create(:ci_build, :running, user: user, project: project) }

          subject { get api(package_url, job_token: job.token) }

          it_behaves_like 'returns package', :project, :maintainer
          it_behaves_like 'returns package', :project, :developer
          it_behaves_like 'returns package', :project, :reporter
          # TODO uncomment when https://gitlab.com/gitlab-org/gitlab/-/issues/370998 is resolved
          # it_behaves_like 'rejects packages access', :project, :guest, :not_found
          it_behaves_like 'rejects packages access', :project, :no_type, :forbidden
        end

        context 'with pipeline' do
          let_it_be(:package1) { create(:npm_package, :with_build, project: project) }

          it 'returns the pipeline info' do
            project.add_developer(user)

            get api(package_url, user)

            expect(response).to have_gitlab_http_status(:ok)
            expect(response).to match_response_schema('public_api/v4/packages/package_with_build')
          end

          context 'when repository access is disabled' do
            before_all do
              project.project_feature.update!(
                repository_access_level: ProjectFeature::DISABLED,
                merge_requests_access_level: ProjectFeature::DISABLED,
                builds_access_level: ProjectFeature::DISABLED
              )
              project.add_reporter(user)
            end

            it 'does not return pipeline info' do
              get api(package_url, user)

              expect(response).to have_gitlab_http_status(:ok)
              expect(json_response).not_to include('pipeline', 'pipelines')
            end
          end
        end
      end
    end

    context 'with versions' do
      before_all { project.add_developer(user) }

      # Otherwise the user activity update can run in only one of the compared requests,
      # depending on a lease left over from an earlier example.
      before do
        User.id_in(user).update_all(last_activity_on: Date.today) # rubocop:disable Rails/Date -- Users::ActivityService compares with Date.today
      end

      def create_version(version)
        create(:npm_package, :with_build, project: project, name: package1.name, version: version)
      end

      it 'avoids N+1 database queries' do
        create_version('1.0.0')

        control = ActiveRecord::QueryRecorder.new { get api(package_url, user) }

        create_version('1.1.0')
        create_version('1.2.0')

        expect { get api(package_url, user) }.not_to exceed_query_limit(control)
        expect(json_response['versions'].pluck('pipeline')).to all(be_present)
      end

      it 'does not load the project of each version' do
        create_version('1.0.0')
        # The first request also records token usage, which would hide the growth.
        get api(package_url, user)

        # The per-version project lookups hit the query cache, so count cached queries too.
        control = ActiveRecord::QueryRecorder.new(skip_cached: false) { get api(package_url, user) }

        %w[1.1.0 1.2.0 1.3.0].each { |version| create_version(version) }

        expect { get api(package_url, user) }.not_to exceed_all_query_limit(control)
      end

      it 'loads only the newest build info of the package and each version, in one query', :aggregate_failures do
        create_list(:package_build_info, 2, :with_pipeline, package: package1)
        version = create_version('1.0.0')
        create(:package_build_info, :with_pipeline, package: version)

        loaded_build_infos = 0
        count_build_infos = ->(*, payload) do
          loaded_build_infos += payload[:record_count] if payload[:class_name] == 'Packages::BuildInfo'
        end

        recorder = ActiveSupport::Notifications.subscribed(count_build_infos, 'instantiation.active_record') do
          ActiveRecord::QueryRecorder.new { get api(package_url, user) }
        end

        expect(recorder.log.grep(/packages_build_infos/).size).to eq(1)
        expect(loaded_build_infos).to eq(2)
        expect(json_response['pipeline']['id']).to eq(package1.build_infos.last.pipeline_id)
        expect(json_response['versions'].sole['pipeline']['id']).to eq(version.build_infos.last.pipeline_id)
      end
    end

    context 'when package has no default status' do
      let!(:package1) { create(:npm_package, :error, project: project) }

      it 'returns 404' do
        subject

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end
  end
end
