# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Environment', feature_category: :environment_management do
  let_it_be(:project, freeze: false) { create(:project, :repository) }
  let(:user) { create(:user) }
  let(:role) { :developer }

  before do
    sign_in(user)
    project.add_role(user, role)
  end

  def auto_stop_button_selector
    %q([data-testid="cancel-auto-stop-button"])
  end

  describe 'environment details page', :js do
    let_it_be(:environment) { create(:environment, project: project) }
    let!(:permissions) { nil }
    let!(:deployment) { nil }
    let!(:action) { nil }

    context 'with auto-stop' do
      let_it_be(:environment) { create(:environment, :will_auto_stop, name: 'staging', project: project) }

      before do
        visit_environment(environment)
      end

      it 'allows user to cancel auto stop' do
        page.find(auto_stop_button_selector).click
        wait_for_all_requests
        expect(page).to have_content('Auto stop successfully canceled.')
        expect(page).not_to have_selector(auto_stop_button_selector)
      end
    end

    context 'with deployments' do
      context 'with upcoming deployments' do
        let(:pipeline) { create(:ci_pipeline, project: project) }
        let(:build) { create(:ci_build, pipeline: pipeline) }

        let!(:runnind_deployment_1) { create(:deployment, environment: environment, deployable: build, status: :running) }
        let!(:runnind_deployment_2) { create(:deployment, environment: environment, deployable: build, status: :running) }
        # Success deployments must have present `finished_at`. We'll backfill in the future.
        # See https://gitlab.com/gitlab-org/gitlab/-/issues/350618 for more information.
        let!(:success_without_finished_at) { create(:deployment, environment: environment, deployable: build, status: :success, finished_at: nil) }

        before do
          visit_environment(environment)
          click_link s_('Environments|Deployment history')
        end

        # This ordering is unexpected and to be fixed.
        # See https://gitlab.com/gitlab-org/gitlab/-/issues/350618 for more information.
        it 'shows upcoming deployments in unordered way' do
          displayed_ids = find_all('[data-testid="deployment-id"]').map(&:text)
          internal_ids = [runnind_deployment_1, runnind_deployment_2, success_without_finished_at].map { |d| d.iid.to_s }
          expect(displayed_ids).to match_array(internal_ids)
        end
      end

      context 'with related deployable present' do
        let_it_be(:pipeline) { create(:ci_pipeline, project: project) }
        let_it_be(:build) { create(:ci_build, :success, pipeline: pipeline, environment: environment.name) }

        let_it_be(:deployment) do
          create(:deployment, :success, environment: environment, deployable: build)
        end

        before do
          visit_environment(environment)
          click_link s_('Environments|Deployment history')
        end

        context 'with manual action' do
          let(:action) do
            create(:ci_build, :manual, pipeline: pipeline, name: 'deploy to production', environment: environment.name)
          end

          context 'when user has ability to trigger deployment' do
            let(:permissions) do
              create(:protected_branch, :developers_can_merge, name: action.ref, project: project)
            end

            it 'does allow to play manual action' do
              expect(action).to be_manual

              click_button('Deploy to…')
              click_button(action.name)

              wait_for_all_requests

              expect(action.reload).to be_pending
            end
          end
        end
      end
    end
  end

  describe 'environment folders', :js do
    context 'when folder name contains special charaters' do
      before do
        create(:environment, project: project, name: 'staging-1.0/review', state: :available)
      end

      it 'renders a correct environment folder' do
        reqs = inspect_requests do
          visit folder_project_environments_path(project, id: 'staging-1.0')
        end

        wait_for_requests

        expect(reqs.first.status_code).to eq(200)
        expect(page).to have_content('Environments / staging-1.0')
      end
    end
  end

  describe 'auto-close environment when branch is deleted' do
    let(:project) { create(:project, :repository) }

    let!(:environment) do
      create(:environment, :with_review_app, project: project, ref: 'feature', user: user)
    end

    it 'user deletes the branch with running environment', :js do
      visit project_branches_filtered_path(project, state: 'all', search: 'feature')

      remove_branch_with_hooks(project, user, 'feature') do
        page.within('.js-branch-feature') do
          within_testid('branch-more-actions') do
            find('.gl-new-dropdown-toggle').click
          end
          find_by_testid('delete-branch-button').click
        end
      end

      visit_environment(environment)
    end

    ##
    # This is a workaround for problem described in #24543
    #
    def remove_branch_with_hooks(project, user, branch)
      params = {
        change: {
          oldrev: project.commit(branch).id,
          newrev: Gitlab::Git::SHA1_BLANK_SHA,
          ref: "refs/heads/#{branch}"
        }
      }

      yield

      # Playing the stop action's manual job updates `p_ci_builds` (`gitlab_ci`), and
      # `Ci::Deployable` defers the matching `Environment`/`Deployment` sync
      # (`gitlab_main_org`) to `run_after_commit` so the two stay in separate production
      # transactions. RSpec's transactional fixtures fire `after_commit` callbacks without
      # a real commit, so both writes land in this example's single wrapping transaction,
      # which the cross-database query analyzer then flags as a violation.
      allow_cross_database_modification_within_transaction(
        url: 'https://gitlab.com/gitlab-org/gitlab/-/work_items/622190'
      ) do
        Git::BranchPushService.new(project, user, params).execute
      end
    end
  end

  def visit_environment(environment)
    visit project_environment_path(environment.project, environment)
  end
end
