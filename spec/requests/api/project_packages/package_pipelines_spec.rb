# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::ProjectPackages, feature_category: :package_registry do
  using RSpec::Parameterized::TableSyntax

  let_it_be_with_reload(:project) { create(:project, :public) }

  let!(:package1) { create(:npm_package, :last_downloaded_at, project: project, version: '3.1.0', name: "@#{project.root_namespace.path}/foo1") }
  let!(:package2) { create(:nuget_package, project: project, version: '2.0.4') }

  describe 'GET /projects/:id/packages/:package_id/pipelines' do
    let(:package_pipelines_url) { "/projects/#{project.id}/packages/#{package1.id}/pipelines" }

    let(:tokens) do
      {
        personal_access_token: personal_access_token.token,
        job_token: job.token
      }
    end

    let_it_be(:personal_access_token) { create(:personal_access_token) }
    let_it_be(:user) { personal_access_token.user }
    let_it_be(:job) { create(:ci_build, :running, user: user, project: project) }
    let(:headers) { {} }

    subject { get api(package_pipelines_url) }

    shared_examples 'returns package pipelines' do |expected_status|
      it 'returns the first page of package pipelines' do
        subject

        expect(response).to have_gitlab_http_status(expected_status)
        expect(response).to match_response_schema('public_api/v4/packages/pipelines')
        expect(json_response.length).to eq(3)
        expect(json_response.pluck('id')).to eq(pipelines.reverse.map(&:id))
      end
    end

    it_behaves_like 'enforcing job token policies', :read_pipelines,
      allow_public_access_for_enabled_project_features: :package_registry do
      let(:request) { get api(package_pipelines_url), params: { job_token: target_job.token } }
    end

    it_behaves_like 'authorizing granular token permissions', :read_package_pipeline do
      before_all { project.add_developer(user) }

      let(:boundary_object) { project }
      let(:request) { get api(package_pipelines_url, personal_access_token: pat) }
    end

    context 'without the need for a license' do
      context 'when the package does not exist' do
        let(:package_pipelines_url) { "/projects/#{project.id}/packages/0/pipelines" }

        it_behaves_like 'returning response status', :not_found
      end

      context 'when there are no pipelines for the package' do
        let(:package_pipelines_url) { "/projects/#{project.id}/packages/#{package2.id}/pipelines" }

        it 'returns an empty response' do
          subject

          expect(response).to have_gitlab_http_status(:success)
          expect(response).to match_response_schema('public_api/v4/packages/pipelines')
          expect(json_response.length).to eq(0)
        end
      end

      context 'with valid package and pipelines' do
        let_it_be(:package1) { create(:npm_package, :last_downloaded_at, project: project, version: '3.1.0', name: "@#{project.root_namespace.path}/foo1") }
        let_it_be(:pipelines) do
          create_list(:ci_pipeline, 3, user: user, project: project).each do |pipeline|
            create(:package_build_info, package: package1, pipeline: pipeline)
          end
        end

        where(:visibility, :user_role, :member, :token_type, :valid_token, :shared_examples_name, :expected_status) do
          :public  | :developer  | true  | :personal_access_token | true  | 'returns package pipelines' | :success
          :public  | :guest      | true  | :personal_access_token | true  | 'returns package pipelines' | :success
          :public  | :developer  | true  | :personal_access_token | false | 'returning response status' | :unauthorized
          :public  | :guest      | true  | :personal_access_token | false | 'returning response status' | :unauthorized
          :public  | :developer  | false | :personal_access_token | true  | 'returns package pipelines' | :success
          :public  | :guest      | false | :personal_access_token | true  | 'returns package pipelines' | :success
          :public  | :developer  | false | :personal_access_token | false | 'returning response status' | :unauthorized
          :public  | :guest      | false | :personal_access_token | false | 'returning response status' | :unauthorized
          :public  | :anonymous  | false | nil                    | true  | 'returns package pipelines' | :success
          :private | :developer  | true  | :personal_access_token | true  | 'returns package pipelines' | :success
          :private | :guest      | true  | :personal_access_token | true  | 'returns package pipelines' | :success
          :private | :developer  | true  | :personal_access_token | false | 'returning response status' | :unauthorized
          :private | :guest      | true  | :personal_access_token | false | 'returning response status' | :unauthorized
          :private | :developer  | false | :personal_access_token | true  | 'returning response status' | :not_found
          :private | :guest      | false | :personal_access_token | true  | 'returning response status' | :not_found
          :private | :developer  | false | :personal_access_token | false | 'returning response status' | :unauthorized
          :private | :guest      | false | :personal_access_token | false | 'returning response status' | :unauthorized
          :private | :anonymous  | false | nil                    | true  | 'returning response status' | :not_found
          :public  | :developer  | true  | :job_token             | true  | 'returns package pipelines' | :success
          :public  | :guest      | true  | :job_token             | true  | 'returns package pipelines' | :success
          :public  | :developer  | true  | :job_token             | false | 'returning response status' | :unauthorized
          :public  | :guest      | true  | :job_token             | false | 'returning response status' | :unauthorized
          :public  | :developer  | false | :job_token             | true  | 'returns package pipelines' | :success
          :public  | :guest      | false | :job_token             | true  | 'returns package pipelines' | :success
          :public  | :developer  | false | :job_token             | false | 'returning response status' | :unauthorized
          :public  | :guest      | false | :job_token             | false | 'returning response status' | :unauthorized
          :private | :developer  | true  | :job_token             | true  | 'returns package pipelines' | :success
          # TODO uncomment the spec below when https://gitlab.com/gitlab-org/gitlab/-/issues/370998 is resolved
          # :private | :guest      | true  | :job_token             | true  | 'returning response status' | :forbidden
          :private | :developer  | true  | :job_token             | false | 'returning response status' | :unauthorized
          :private | :guest      | true  | :job_token             | false | 'returning response status' | :unauthorized
          :private | :developer  | false | :job_token             | true  | 'returning response status' | :forbidden
          :private | :guest      | false | :job_token             | true  | 'returning response status' | :forbidden
          :private | :developer  | false | :job_token             | false | 'returning response status' | :unauthorized
          :private | :guest      | false | :job_token             | false | 'returning response status' | :unauthorized
        end

        with_them do
          subject { get api(package_pipelines_url), headers: headers }

          let(:invalid_token) { 'invalid-token123' }
          let(:token) { valid_token ? tokens[token_type] : invalid_token }
          let(:headers) do
            case token_type
            when :personal_access_token
              { Gitlab::Auth::AuthFinders::PRIVATE_TOKEN_HEADER => token }
            when :job_token
              { Gitlab::Auth::AuthFinders::JOB_TOKEN_HEADER => token }
            when nil
              {}
            end
          end

          before do
            project.update!(visibility: visibility.to_s)
            project.send("add_#{user_role}", user) if member && user_role != :anonymous
          end

          it_behaves_like params[:shared_examples_name], params[:expected_status]
        end

        context 'when a pipeline belongs to another private project' do
          let_it_be(:private_project) { create(:project, :private) }
          let_it_be(:private_pipeline) do
            create(:ci_pipeline, project: private_project).tap do |pipeline|
              create(:package_build_info, package: package1, pipeline: pipeline)
            end
          end

          shared_examples 'hiding the private project pipeline' do
            it 'does not return the pipeline from the private project' do
              subject

              expect(response).to have_gitlab_http_status(:success)
              expect(json_response.pluck('id')).to match_array(pipelines.map(&:id))
            end
          end

          context 'with an anonymous user on a public project' do
            it_behaves_like 'hiding the private project pipeline'
          end

          context 'with a job token' do
            subject do
              get api(package_pipelines_url), headers: { Gitlab::Auth::AuthFinders::JOB_TOKEN_HEADER => job.token }
            end

            # The user can read the private project, so only the job token scope hides its pipeline.
            before_all do
              project.add_developer(user)
              private_project.add_developer(user)
            end

            it_behaves_like 'hiding the private project pipeline'
          end
        end
      end

      context 'when paginating' do
        shared_examples 'returns the default number of pipelines' do
          it 'returns 20 pipelines' do
            subject

            expect(json_response.size).to eq(20)
          end
        end

        shared_examples 'returns an error about the invalid per_page value' do
          it 'responds with bad request and a per_page error' do
            subject

            expect(response).to have_gitlab_http_status(:bad_request)
            expect(json_response['error']).to match(/per_page does not have a valid value/)
          end
        end

        context 'without pagination params' do
          let!(:pipelines) do
            create_list(:package_build_info, 21, :with_pipeline, package: package1)
          end

          it_behaves_like 'returns the default number of pipelines'
        end

        context 'with valid per_page value' do
          let(:per_page) { 5 }

          let!(:pipelines) do
            create_list(:package_build_info, 6, :with_pipeline, package: package1)
          end

          subject { get api(package_pipelines_url, user), params: { per_page: per_page } }

          it 'returns the correct number of pipelines' do
            subject

            expect(json_response.size).to eq(per_page)
          end
        end

        context 'with invalid pagination params' do
          subject { get api(package_pipelines_url, user), params: { per_page: per_page } }

          context 'with non-positive per_page' do
            let(:per_page) { -2 }

            it_behaves_like 'returns an error about the invalid per_page value'
          end

          context 'with a too high value for per_page' do
            let(:per_page) { 21 }

            it_behaves_like 'returns an error about the invalid per_page value'
          end
        end

        context 'with valid pagination params' do
          let_it_be(:package1) { create(:npm_package, :last_downloaded_at, project: project) }
          let_it_be(:build_info1) { create(:package_build_info, :with_pipeline, package: package1) }
          let_it_be(:build_info2) { create(:package_build_info, :with_pipeline, package: package1) }
          let_it_be(:build_info3) { create(:package_build_info, :with_pipeline, package: package1) }

          let(:pipeline1) { build_info1.pipeline }
          let(:pipeline2) { build_info2.pipeline }
          let(:pipeline3) { build_info3.pipeline }

          let(:per_page) { 2 }

          it_behaves_like 'an endpoint with keyset pagination' do
            let(:first_record) { pipeline3 }
            let(:second_record) { pipeline2 }
            let(:api_call) { api(package_pipelines_url, user) }
          end

          context 'with no cursor supplied' do
            subject { get api(package_pipelines_url, user), params: { per_page: per_page } }

            it 'returns first 2 pipelines' do
              subject

              expect(json_response.pluck('id')).to contain_exactly(pipeline3.id, pipeline2.id)
            end
          end

          context 'with a cursor parameter' do
            let(:cursor) { Base64.urlsafe_encode64(Gitlab::Json.dump(cursor_attributes)) }

            subject { get api(package_pipelines_url, user), params: { per_page: per_page, cursor: cursor } }

            before do
              subject
            end

            context 'with a cursor for the next page' do
              let(:cursor_attributes) { { "id" => build_info2.id, "_kd" => "n" } }

              it 'returns the next page of records' do
                expect(json_response.pluck('id')).to contain_exactly(pipeline1.id)
              end
            end

            context 'with a cursor for the previous page' do
              let(:cursor_attributes) { { "id" => build_info1.id, "_kd" => "p" } }

              it 'returns the previous page of records' do
                expect(json_response.pluck('id')).to contain_exactly(pipeline3.id, pipeline2.id)
              end
            end
          end
        end
      end
    end

    context 'with repository access' do
      let_it_be(:package1) { create(:npm_package, :last_downloaded_at, project: project, version: '3.1.0', name: "@#{project.root_namespace.path}/foo1") }
      let_it_be(:pipelines) do
        create_list(:ci_pipeline, 3, user: user, project: project).each do |pipeline|
          create(:package_build_info, package: package1, pipeline: pipeline)
        end
      end

      let_it_be(:job) { create(:ci_build, :running, user: user, project: project) }

      before_all { project.add_reporter(user) }

      context 'when access is disabled' do
        before_all do
          project.project_feature.update!(
            repository_access_level: ProjectFeature::DISABLED,
            merge_requests_access_level: ProjectFeature::DISABLED,
            builds_access_level: ProjectFeature::DISABLED
          )
        end

        context 'with user auth' do
          it 'returns forbidden' do
            get api(package_pipelines_url, user)

            expect(response).to have_gitlab_http_status(:forbidden)
          end
        end

        context 'with job token auth' do
          it 'returns the pipelines' do
            get api(package_pipelines_url, job_token: job.token)

            expect(response).to have_gitlab_http_status(:success)
            expect(response).to match_response_schema('public_api/v4/packages/pipelines')
            expect(json_response.length).to eq(3)
          end
        end
      end

      context 'when access is enabled' do
        context 'with user auth' do
          it 'returns package pipelines' do
            get api(package_pipelines_url, user)

            expect(response).to have_gitlab_http_status(:success)
            expect(response).to match_response_schema('public_api/v4/packages/pipelines')
            expect(json_response.length).to eq(3)
          end
        end

        context 'with job token auth' do
          it 'returns package pipelines' do
            get api(package_pipelines_url, job_token: job.token)

            expect(response).to have_gitlab_http_status(:success)
            expect(response).to match_response_schema('public_api/v4/packages/pipelines')
            expect(json_response.length).to eq(3)
          end
        end
      end
    end
  end
end
