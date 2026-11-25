# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Environments page', :js, feature_category: :continuous_delivery do
  include Spec::Support::Helpers::ModalHelpers

  let(:project) { create(:project) }
  let(:user) { create(:user) }
  let(:role) { :developer }

  before do
    project.add_role(user, role)
    sign_in(user)
  end

  def actions_button_selector
    '[data-testid="environment-actions-button"]'
  end

  def action_link_selector
    '[data-testid="manual-action-link"]'
  end

  describe 'environments table' do
    let!(:environment) do
      create(:environment, project: project, state: :available)
    end

    context 'when there are successful deployments' do
      let_it_be(:project) { create(:project, :repository) }

      let!(:deployment) do
        create(:deployment, :success, environment: environment, sha: project.commit.id)
      end

      context 'when there is a delayed job' do
        let!(:pipeline) { create(:ci_pipeline, project: project) }
        let!(:build) { create(:ci_build, pipeline: pipeline) }

        let!(:delayed_job) do
          create(:ci_build, :scheduled, pipeline: pipeline, name: 'delayed job')
        end

        let!(:deployment) do
          create(:deployment, :success, environment: environment, deployable: build, sha: project.commit.id)
        end

        before do
          visit_environments(project)
        end

        context 'when user played a delayed job immediately' do
          before do
            find(actions_button_selector).click
            accept_gl_confirm do
              find(action_link_selector).click
            end
          end

          it 'enqueues the delayed job' do
            # The play action fires a client-side mutation with no distinct success
            # indicator on the button (it only transitions play-icon -> spinner ->
            # play-icon), so poll the backend state instead of racing the transient
            # loading UI.
            wait_for('delayed job to be enqueued', reload: false) do
              delayed_job.reload.pending?
            end

            expect(delayed_job).to be_pending
          end
        end
      end
    end

    context 'when there is a failed deployment' do
      let_it_be(:project) { create(:project, :repository) }

      let!(:deployment) do
        create(:deployment, :failed, environment: environment, sha: project.commit.id)
      end

      it 'does not show deployments' do
        visit_environments(project)

        expect(page).to have_content(s_('Environments|There are no deployments for this environment yet. Learn more about setting up deployments.'))
      end
    end

    describe 'stop actions' do
      let_it_be(:project) { create(:project, :repository) }

      let(:warning_message) { 'There is no action:stop defined for this environment' }

      where(status: %i[success failed canceled])

      with_them do
        before do
          pipeline = create(:ci_pipeline, status, project: project)
          build = create(:ci_build, status, pipeline: pipeline)
          create(:ci_build, :manual, project: project, pipeline: pipeline, name: 'stop_action')
          create(:deployment, status, environment: environment, deployable: build, sha: project.commit.id, on_stop: 'stop_action')

          visit_environments(project)
        end

        it 'shows a stop action dialog without a warning message' do
          click_button(_('Stop'))

          within('.modal-body') do
            expect(page).not_to have_content(warning_message)
          end
        end
      end
    end
  end

  describe 'creating a new environment' do
    before do
      visit_environments(project)
    end

    context 'user is a developer' do
      let(:role) { :developer }

      it 'developer creates a new environment with a valid name' do
        click_link 'Create an environment'
        fill_in('Name', with: 'production')
        click_on 'Save'

        expect(page).to have_content('production')
      end

      it 'developer creates a new environment with invalid name' do
        click_link 'Create an environment'
        fill_in('Name', with: 'name,with,commas')
        click_on 'Save'

        expect(page).to have_content('Name can contain only letters')
      end
    end
  end

  describe 'environments folders' do
    describe 'available environments' do
      before do
        create(:environment, :will_auto_stop, project: project, name: 'staging/review-1', state: :available)
        create(:environment, :will_auto_stop, project: project, name: 'staging/review-2', state: :available)
      end

      it 'shows folder name linked to the folder page' do
        visit_environments(project)
        wait_for_requests

        expect(page).not_to have_content 'review-1'
        expect(page).not_to have_content 'review-2'
        expect(page).to have_content 'staging 2'

        expect(page).to have_link('staging')

        click_link 'staging'

        expect(page).to have_current_path(folder_project_environments_path(project, 'staging'))
        expect(page).to have_content 'Environments / staging'
      end
    end

    describe 'stopped environments' do
      before do
        create(:environment, :will_auto_stop, project: project, name: 'staging/review-1', state: :stopped)
        create(:environment, :will_auto_stop, project: project, name: 'staging/review-2', state: :stopped)
      end

      it 'shows folder name linked to the folder page' do
        visit_environments(project, scope: 'stopped')
        wait_for_requests

        expect(page).not_to have_content 'review-1'
        expect(page).not_to have_content 'review-2'
        expect(page).to have_content 'staging 2'

        expect(page).to have_link('staging')

        click_link 'staging'

        expect(page).to have_current_path(folder_project_environments_path(project, 'staging'))
        expect(page).to have_content 'Environments / staging'
      end
    end
  end

  def visit_environments(project, **opts)
    visit project_environments_path(project, **opts)
    wait_for_requests
  end
end
