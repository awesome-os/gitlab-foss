# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Projects::ForksController, feature_category: :source_code_management do
  include ProjectForksHelper

  let(:user) { create(:user) }
  let_it_be_with_reload(:project) { create(:project, :public, :repository) }
  let(:forked_project) { Projects::ForkService.new(project, user, name: 'Some name').execute[:project] }
  let(:group) { create(:group) }

  before do
    group.add_owner(user)
  end

  shared_examples 'forking disabled' do
    let(:project) { create(:project, :private, :repository, :forking_disabled, developers: user) }

    before do
      sign_in(user)
    end

    it 'returns with 404' do
      subject

      expect(response).to have_gitlab_http_status(:not_found)
    end
  end

  describe 'GET index' do
    def get_forks(search: nil)
      get :index,
        params: {
          namespace_id: project.namespace,
          project_id: project,
          search: search
        }
    end

    context 'when fork is public' do
      before do
        forked_project.update_attribute(:visibility_level, Project::PUBLIC)
      end

      it 'is visible for non logged in users' do
        get_forks

        expect(assigns[:forks]).to be_present
      end

      it 'forks counts are correct' do
        get_forks

        expect(assigns[:total_forks_count]).to eq(1)
        expect(assigns[:public_forks_count]).to eq(1)
        expect(assigns[:internal_forks_count]).to eq(0)
        expect(assigns[:private_forks_count]).to eq(0)
      end

      context 'after search' do
        it 'forks counts are correct' do
          get_forks(search: 'Non-matching query')

          expect(assigns[:total_forks_count]).to eq(1)
          expect(assigns[:public_forks_count]).to eq(1)
          expect(assigns[:internal_forks_count]).to eq(0)
          expect(assigns[:private_forks_count]).to eq(0)
        end
      end

      context 'when unsupported keys are provided' do
        it 'ignores them' do
          get :index, params: {
            namespace_id: project.namespace,
            project_id: project,
            user: 'unsupported'
          }

          expect(assigns[:forks]).to be_present
        end
      end
    end

    context 'when fork is internal' do
      before do
        forked_project.update!(visibility_level: Project::INTERNAL, group: group)
      end

      it 'forks counts are correct' do
        get_forks

        expect(assigns[:total_forks_count]).to eq(1)
        expect(assigns[:public_forks_count]).to eq(0)
        expect(assigns[:internal_forks_count]).to eq(1)
        expect(assigns[:private_forks_count]).to eq(0)
      end
    end

    context 'when fork is private' do
      before do
        forked_project.update!(visibility_level: Project::PRIVATE, group: group)
      end

      shared_examples 'forks counts' do
        it 'forks counts are correct' do
          get_forks

          expect(assigns[:total_forks_count]).to eq(1)
          expect(assigns[:public_forks_count]).to eq(0)
          expect(assigns[:internal_forks_count]).to eq(0)
          expect(assigns[:private_forks_count]).to eq(1)
        end
      end

      it 'is not visible for non logged in users' do
        get_forks

        expect(assigns[:forks]).to be_blank
      end

      include_examples 'forks counts'

      context 'when user is logged in' do
        before do
          sign_in(project.creator)
        end

        context 'when user is not a Project member neither a group member' do
          it 'does not see the Project listed' do
            get_forks

            expect(assigns[:forks]).to be_blank
          end
        end

        context 'when user is a member of the Project' do
          before do
            forked_project.add_developer(project.creator)
          end

          it 'sees the project listed' do
            get_forks

            expect(assigns[:forks]).to be_present
          end

          include_examples 'forks counts'
        end

        context 'when user is a member of the Group' do
          before do
            forked_project.group.add_developer(project.creator)
          end

          it 'sees the project listed' do
            get_forks

            expect(assigns[:forks]).to be_present
          end

          include_examples 'forks counts'
        end
      end
    end
  end

  describe 'GET new' do
    let(:format) { :html }

    subject(:do_request) do
      get :new, format: format, params: { namespace_id: project.namespace, project_id: project }
    end

    context 'when user is signed in' do
      before do
        sign_in(user)
      end

      it 'responds with status 200' do
        request

        expect(response).to have_gitlab_http_status(:ok)
      end

      context 'when JSON is requested' do
        let(:format) { :json }

        it 'responds with user namespace + groups' do
          do_request

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response['namespaces'].length).to eq(2)
          expect(json_response['namespaces'][0]['id']).to eq(user.namespace.id)
          expect(json_response['namespaces'][1]['id']).to eq(group.id)
        end

        context 'N+1 queries' do
          before do
            create(:fork_network, root_project: project)
          end

          it 'avoids N+1 queries' do
            do_request = -> { get :new, format: format, params: { namespace_id: project.namespace, project_id: project } }

            # warm up
            do_request.call

            control = ActiveRecord::QueryRecorder.new { do_request.call }

            create(:group, :public).add_owner(user)

            expect { do_request.call }.not_to exceed_query_limit(control)
          end
        end
      end
    end

    context 'when user is not signed in' do
      it 'redirects to the sign-in page' do
        sign_out(user)

        subject

        expect(response).to redirect_to(new_user_session_path)
      end
    end

    it_behaves_like 'forking disabled'
  end

  describe 'POST create' do
    let(:params) do
      {
        namespace_id: project.namespace,
        project_id: project,
        namespace_key: user.namespace.id
      }
    end

    let(:created_project) do
      Namespace
        .find_by_id(params[:namespace_key])
        .projects
        .find_by_path(params.fetch(:path, project.path))
    end

    subject do
      post :create, params: params
    end

    context 'when user is signed in' do
      before do
        sign_in(user)
      end

      it 'responds with status 302' do
        subject

        expect(response).to have_gitlab_http_status(:found)
        expect(response).to redirect_to(namespace_project_import_path(user.namespace, project))
      end

      context 'when target namespace is not valid for forking' do
        let(:params) { super().merge(namespace_key: another_group.id) }
        let(:another_group) { create :group }

        it 'responds with :not_found' do
          subject

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end

      context 'when fork already exists' do
        before do
          forked_project
        end

        it 'responds with status 302' do
          subject

          expect(response).to have_gitlab_http_status(:found)
          expect(response).to redirect_to(namespace_project_import_path(user.namespace, project))
        end
      end

      context 'when fork process fails' do
        before do
          allow_next_instance_of(Projects::ForkService) do |instance|
            allow(instance).to receive(:execute).and_return(ServiceResponse.error(message: 'Error'))
          end
        end

        it 'responds with an error page' do
          subject

          expect(response).to have_gitlab_http_status(:ok)
          expect(response).to render_template(:error)
        end
      end

      context 'continue params' do
        let(:params) do
          {
            namespace_id: project.namespace,
            project_id: project,
            namespace_key: user.namespace.id,
            continue: continue_params
          }
        end

        let(:continue_params) do
          {
            to: '/-/ide/project/path',
            notice: 'message'
          }
        end

        it 'passes continue params to the redirect' do
          subject

          expect(response).to have_gitlab_http_status(:found)
          expect(response).to redirect_to(namespace_project_import_path(user.namespace, project, continue: continue_params))
        end

        context 'when coming from an edit flow' do
          let(:helpers) { ApplicationController.helpers }
          let(:continue_params) do
            {
              to: project_tree_path(project),
              notice: "#{helpers.edit_in_new_fork_notice} Try to upload a file again.",
              notice_now: helpers.edit_in_new_fork_notice_now
            }
          end

          let(:existing_fork_notice) { "#{helpers.edit_in_existing_fork_notice} Try to upload a file again." }

          shared_examples 'uses the existing fork' do
            def set_import_status(status)
              ProjectImportState.find_or_initialize_by(project: existing_fork).update!(status: status)
            end

            it 'redirects with a notice about the existing fork and creates no project' do
              set_import_status(:finished)

              expect { subject }.not_to change { Project.count }

              expect(response).to redirect_to(project_tree_path(project))
              expect(flash[:notice]).to eq(existing_fork_notice)
            end

            it 'keeps the existing fork notice while the fork is still importing' do
              set_import_status(:started)

              subject

              expect(response).to redirect_to(
                namespace_project_import_path(
                  user.namespace, existing_fork,
                  continue: continue_params.merge(
                    notice: existing_fork_notice, notice_now: helpers.edit_in_existing_fork_notice_now
                  )
                )
              )
            end
          end

          context 'when the user has a fork at the same path' do
            let!(:existing_fork) { forked_project }

            it_behaves_like 'uses the existing fork'
          end

          context 'when the user renamed the path of their fork' do
            let!(:existing_fork) do
              fork_project(
                project, user,
                namespace: user.namespace,
                target_project: create(:project, namespace: user.namespace, path: 'renamed-fork', name: project.name)
              )
            end

            it_behaves_like 'uses the existing fork'
          end

          shared_examples 'explains the path conflict' do
            it 'explains the path conflict and creates no fork' do
              expect { subject }.not_to change { Project.count }

              expect(response).to have_gitlab_http_status(:ok)
              expect(response).to render_template(:error)
              expect(assigns(:fork_response).message).to eq(
                "You already have a project at #{unrelated_project.full_path}, so a fork can't be created there. " \
                  "Choose a different project slug."
              )
            end
          end

          context 'when an unrelated project has the same path' do
            let!(:unrelated_project) { create(:project, namespace: user.namespace, path: project.path) }

            it_behaves_like 'explains the path conflict'
          end

          context 'when an unrelated project has the same path in a different case' do
            let!(:unrelated_project) { create(:project, namespace: user.namespace, path: project.path.upcase) }

            it_behaves_like 'explains the path conflict'
          end
        end
      end

      context 'when an unrelated project has the same path and no continue params are passed' do
        before do
          create(:project, namespace: user.namespace, path: project.path)
        end

        it 'renders the fork service error' do
          subject

          expect(response).to render_template(:error)
          expect(assigns(:fork_response).message).to include('Path has already been taken')
        end
      end

      context 'custom attributes set' do
        let(:params) { super().merge(path: 'something_custom', name: 'Something Custom', description: 'Something Custom', visibility: 'private') }

        it 'creates a project with custom values' do
          subject

          expect(response).to have_gitlab_http_status(:found)
          expect(response).to redirect_to(namespace_project_import_path(user.namespace, params[:path]))
          expect(created_project.path).to eq(params[:path])
          expect(created_project.name).to eq(params[:name])
          expect(created_project.description).to eq(params[:description])
          expect(created_project.visibility).to eq(params[:visibility])
        end
      end
    end

    context 'when user is not signed in' do
      it 'redirects to the sign-in page' do
        sign_out(user)

        subject

        expect(response).to redirect_to(new_user_session_path)
      end
    end

    it_behaves_like 'forking disabled'
  end
end
