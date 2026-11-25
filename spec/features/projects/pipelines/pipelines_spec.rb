# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Pipelines', :js, :clean_gitlab_redis_cache, feature_category: :continuous_integration do
  include ListboxHelpers
  include Spec::Support::Helpers::ModalHelpers
  include Spec::Support::Helpers::GraphqlSubscriptionHelpers

  let(:project) { create(:project) }

  context 'when user is logged in' do
    let(:user) { create(:user) }

    before do
      sign_in(user)

      project.add_developer(user)
      project.update!(auto_devops_attributes: { enabled: false })
    end

    describe 'GET /:project/-/pipelines' do
      let_it_be_with_reload(:project) { create(:project, :repository) }

      let!(:pipeline) do
        create(
          :ci_pipeline,
          project: project,
          ref: 'master',
          status: 'running',
          sha: project.commit.id
        )
      end

      context 'when pipeline is cancelable' do
        let!(:job) do
          create(:ci_build, pipeline: pipeline)
        end

        before do
          stub_const("::Projects::PipelinesController::POLLING_INTERVAL", 1)
          job.run

          # The list learns about status changes and new pipelines through the
          # ciPipelineStatusesUpdated subscription; a trigger fired before the
          # browser has subscribed is lost.
          wait_for_new_graphql_subscription('pipelineStatusesUpdated') do
            visit_project_pipelines
          end
        end

        context 'when canceling support is disabled' do
          context 'when canceling' do
            it 'indicates that pipeline was canceled', :sidekiq_inline, quarantine: 'https://gitlab.com/gitlab-org/quality/test-failure-issues/-/issues/9504' do
              find('.js-pipelines-cancel-button').click
              click_button 'Stop pipeline'

              wait_for_requests

              expect(page).to have_selector('[data-testid="ci-icon"]', text: 'Canceled')
              expect(page).not_to have_selector('.js-pipelines-cancel-button')
            end

            it 'targets the pipeline the cancel action was invoked on' do
              expect(page).to have_selector('[data-testid="pipeline-table-row"]', count: 1)

              find('.js-pipelines-cancel-button').click

              within_testid 'pipeline-stop-modal' do
                expect(page).to have_content("Stop pipeline ##{pipeline.id}?")
              end

              new_pipeline = create(
                :ci_pipeline,
                :running,
                project: project,
                source: Enums::Ci::Pipeline.sources[:push],
                ref: 'master',
                sha: project.commit.id
              )
              # A pipeline created directly by the factory never transitions, so
              # fire the subscription update the list uses to pick up new pipelines.
              GraphqlTriggers.ci_pipeline_statuses_updated(new_pipeline)

              expect(page).to have_selector('[data-testid="pipeline-table-row"]', count: 2)

              within_testid 'pipeline-stop-modal' do
                expect(page).to have_content("Stop pipeline ##{pipeline.id}?")
              end
            end
          end
        end

        context 'when canceling support is enabled' do
          include_context 'when canceling support'

          context 'when canceling' do
            before do
              find('.js-pipelines-cancel-button').click
              click_button 'Stop pipeline'
              wait_for_requests
            end

            it 'indicates that pipeline is canceling', :sidekiq_inline do
              expect(page).to have_selector('[data-testid="ci-icon"]', text: 'Canceling')
              expect(page).not_to have_selector('.js-pipelines-cancel-button')
            end
          end
        end
      end

      context 'when pipeline is retryable', :sidekiq_might_not_need_inline do
        let!(:build) do
          create(:ci_build, pipeline: pipeline)
        end

        before do
          build.drop
          visit_project_pipelines
        end

        context 'when retrying' do
          before do
            find('.js-pipelines-retry-button').click
            wait_for_requests
          end

          it 'shows running pipeline that is not retryable' do
            expect(page).not_to have_selector('.js-pipelines-retry-button')
            expect(page).to have_selector('[data-testid="ci-icon"]', text: 'Running')
          end
        end
      end

      context 'with manual actions' do
        let!(:manual) do
          create(:ci_build, :manual,
            pipeline: pipeline,
            name: 'manual build')
        end

        before do
          visit_project_pipelines
        end

        it 'has a dropdown with play button that runs manual job' do
          expect(page).to have_selector('[data-testid="pipelines-manual-actions-dropdown"] [data-testid="play-icon"]')

          find_by_testid('pipelines-manual-actions-dropdown').click

          wait_for_requests

          click_button('manual build')

          wait_for_all_requests

          expect(manual.reload).to be_pending
        end
      end

      context 'when there is a delayed job' do
        let!(:delayed_job) do
          create(:ci_build, :scheduled,
            pipeline: pipeline,
            name: 'delayed job 1',
            scheduled_at: 2.hours.since + 2.minutes)
        end

        before do
          visit_project_pipelines
        end

        context 'when delayed job is expired already' do
          let!(:delayed_job) do
            create(:ci_build, :expired_scheduled,
              pipeline: pipeline,
              name: 'delayed job 1')
          end

          it "shows 00:00:00 as the remaining time" do
            find_by_testid('pipelines-manual-actions-dropdown').click

            wait_for_requests

            expect(page).to have_content("00:00:00")
          end
        end

        context 'when user played a delayed job immediately' do
          let(:manual_action_selector) { '[data-testid="pipelines-manual-actions-dropdown"] button' }
          let(:manual_action_dropdown) { '[data-testid="pipelines-manual-actions-dropdown"]' }

          before do
            find(manual_action_selector).click
            accept_gl_confirm do
              click_button 'delayed job 1'
            end

            # Click on the manual action dropdown and check if a request has been made
            find(manual_action_selector).click
            within(manual_action_dropdown) { find('.gl-spinner') }
            within(manual_action_dropdown) { find_by_testid('play-icon') }

            wait_for_requests
          end

          it 'enqueues the delayed job' do
            expect(delayed_job.reload).to be_pending
          end
        end
      end

      context 'for generic statuses' do
        context 'when preparing' do
          let!(:pipeline) do
            create(:ci_pipeline,
              status: 'preparing', project: project)
          end

          let!(:status) do
            create(:generic_commit_status,
              :preparing, pipeline: pipeline)
          end

          before do
            visit_project_pipelines
          end

          it 'is cancelable and preparing' do
            expect(page).to have_selector('.js-pipelines-cancel-button')
            expect(page).to have_selector('[data-testid="ci-icon"]', text: 'Preparing')
          end
        end

        context 'when running' do
          let!(:running) do
            create(:generic_commit_status,
              status: 'running',
              pipeline: pipeline)
          end

          before do
            visit_project_pipelines
          end

          it 'is running and cancelable', :aggregate_failures do
            expect(page).to have_selector('.js-pipelines-cancel-button')
            expect(page).to have_selector('[data-testid="ci-icon"]', text: 'Running')
          end

          context 'when canceling' do
            before do
              find('.js-pipelines-cancel-button').click
              click_button 'Stop pipeline'
            end

            it 'indicates that pipeline was canceled', :sidekiq_might_not_need_inline do
              expect(page).not_to have_selector('.js-pipelines-cancel-button')
              expect(page).to have_selector('[data-testid="ci-icon"]', text: 'Canceled')
            end
          end
        end

        context 'when failed' do
          let!(:status) do
            create(:generic_commit_status, :pending,
              pipeline: pipeline)
          end

          before do
            status.drop
            visit_project_pipelines
          end

          it 'is not retryable and has a failed pipeline', :aggregate_failures, :sidekiq_inline do
            expect(page).not_to have_selector('.js-pipelines-retry-button')
            expect(page).to have_selector('[data-testid="ci-icon"]', text: 'Failed')
          end
        end
      end

      context 'downloadable pipelines' do
        context 'with artifacts' do
          let!(:with_artifacts) do
            build = create(:ci_build, :success,
              pipeline: pipeline,
              name: 'rspec tests')

            create(:ci_job_artifact, :codequality, job: build)
            create(:ci_job_artifact, :archive, job: build)
          end

          before do
            visit_project_pipelines
          end

          it 'lists the downloadable artifacts in the dropdown', :aggregate_failures do
            find('[data-testid="pipeline-multi-actions-dropdown"] button').click

            within_testid('pipeline-multi-actions-dropdown') do
              expect(page).to have_link('rspec tests:archive')
              expect(page).to have_link('rspec tests:codequality')
            end
          end
        end

        context 'with artifacts expired' do
          let!(:with_artifacts_expired) do
            create(:ci_build, :expired, :success,
              pipeline: pipeline,
              name: 'rspec')
          end

          before do
            visit_project_pipelines
          end

          it { expect(page).not_to have_selector('[data-testid="artifact-item"]') }
        end

        context 'with trace artifact' do
          before do
            create(:ci_build, :success, :trace_artifact, pipeline: pipeline)

            visit_project_pipelines
          end

          it 'does not show trace artifact as artifacts' do
            expect(page).not_to have_selector('[data-testid="artifact-item"]')
          end
        end
      end

      context 'mini pipeline graph' do
        let(:build_stage) { create(:ci_stage, pipeline: pipeline, name: 'build', position: 0) }

        let!(:build) do
          create(:ci_build, :pending, pipeline: pipeline, ci_stage: build_stage, name: 'build')
        end

        before do
          visit_project_pipelines
        end

        context 'when clicking a stage badge' do
          it 'is possible to cancel pending build' do
            find_by_testid('pipeline-mini-graph-dropdown-toggle').click

            wait_for_requests

            find_by_testid('ci-action-button').click
            wait_for_requests

            expect(build.reload).to be_canceled
          end

          context 'manual job' do
            let!(:build) do
              create(:ci_build, :manual, pipeline: pipeline, ci_stage: build_stage, name: 'manual-build')
            end

            it 'is possible to play manual build' do
              find_by_testid('pipeline-mini-graph-dropdown-toggle').click

              wait_for_requests

              within first('[data-testid="ci-job-item"]') do
                expect(find_by_testid('play-icon')).to be_visible
              end

              find_by_testid('ci-action-button').click
              wait_for_requests

              element = find_by_testid('pipeline-mini-graph-dropdown-toggle')
              expect(element['aria-expanded']).to eq "true"
              expect(element).to be_visible
            end
          end
        end
      end

      context 'with pipeline key selection' do
        before do
          visit_project_pipelines
          wait_for_requests
        end

        it 'changes the Pipeline ID column link to Pipeline IID and persists', :aggregate_failures do
          expect(page).to have_link(text: "##{pipeline.id}")

          select_from_listbox('Show Pipeline IID', from: 'Show Pipeline ID')

          expect(page).to have_link(text: "##{pipeline.iid}")

          visit_project_pipelines
          wait_for_requests

          expect(page).to have_link(text: "##{pipeline.iid}")
        end
      end
    end

    describe 'POST /:project/-/pipelines' do
      let_it_be_with_reload(:project) { create(:project, :repository) }

      before do
        visit new_project_pipeline_path(project)
      end

      context 'for valid commit' do
        before do
          click_button project.default_branch
          wait_for_requests

          select_listbox_item('spooky-stuff')
          wait_for_requests
        end

        context 'with gitlab-ci.yml' do
          before do
            stub_ci_pipeline_to_return_yaml_file
          end

          subject(:run_pipeline) do
            click_button 'New pipeline'

            wait_for_requests
          end

          it 'creates a new pipeline' do
            expect { run_pipeline }.to change { Ci::Pipeline.count }.by(1)

            expect(Ci::Pipeline.last).to be_web
          end

          context 'when variables are specified' do
            before do
              project.update!(ci_pipeline_variables_minimum_override_role: :developer)
            end

            it 'creates a new pipeline with variables' do
              within_testid('ci-variable-row-container') do
                find_by_testid('pipeline-form-ci-variable-key-field').set('key_name')
                find_by_testid('pipeline-form-ci-variable-value-field').set('value')
              end

              expect do
                click_button 'New pipeline'
                wait_for_requests
              end
                .to change { Ci::Pipeline.count }.by(1)

              expect(Ci::Pipeline.last.variables.map { |var| var.slice(:key, :value) })
                .to eq [{ key: "key_name", value: "value" }.with_indifferent_access]
            end
          end
        end

        context 'without gitlab-ci.yml' do
          before do
            click_button 'New pipeline'
            wait_for_requests
          end

          it { expect(page).to have_content('Missing CI config file') }

          it 'creates a pipeline after first request failed and a valid gitlab-ci.yml file is available when trying again' do
            stub_ci_pipeline_to_return_yaml_file

            expect do
              click_button 'New pipeline'
              wait_for_requests
            end
              .to change { Ci::Pipeline.count }.by(1)
          end
        end
      end
    end

    describe 'Run Pipelines' do
      let_it_be_with_reload(:project) { create(:project, :repository) }

      before do
        visit new_project_pipeline_path(project)
      end

      describe 'new pipeline page' do
        it 'has field to add a new pipeline' do
          expect(page).to have_button project.default_branch
          expect(page).to have_content('Run for')
        end
      end

      describe 'find pipelines' do
        it 'shows filtered pipelines' do
          click_button project.default_branch
          expect_listbox_item(project.default_branch)

          send_keys('2-mb-file')

          expect_listbox_item('2-mb-file')
        end
      end
    end
  end

  context 'when user is not logged in' do
    before do
      project.update!(auto_devops_attributes: { enabled: false })

      visit_project_pipelines
    end

    context 'when project is public' do
      let_it_be_with_reload(:project) { create(:project, :public, :repository) }

      context 'without pipelines' do
        it { expect(page).to have_content 'This project is not currently set up to run pipelines.' }
      end
    end

    context 'when project is private' do
      let_it_be_with_reload(:project) { create(:project, :private, :repository) }

      it 'redirects the user to sign_in and displays the flash alert' do
        expect(page).to have_content 'Sign in or sign up before continuing'
        expect(page).to have_current_path("/users/sign_in")
      end
    end
  end

  def visit_project_pipelines(**query)
    visit project_pipelines_path(project, query)
  end
end
