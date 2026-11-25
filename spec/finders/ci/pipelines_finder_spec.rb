# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ci::PipelinesFinder, feature_category: :continuous_integration do
  let_it_be(:project) { create(:project, :public, :repository) }
  let_it_be(:empty_project) { create(:project, :public) }
  let(:current_user) { nil }
  let(:params) { {} }

  subject(:execute) { described_class.new(project, current_user, params).execute }

  describe "#execute" do
    context 'when params is empty' do
      let(:params) { {} }
      let_it_be(:pipelines) { create_list(:ci_pipeline, 2, project: project) }

      it 'returns all pipelines' do
        is_expected.to match_array(pipelines)
      end
    end

    %w[running pending].each do |target|
      context "when scope is #{target}" do
        let(:params) { { scope: target } }
        let_it_be(:pipeline) { create(:ci_pipeline, project: project, status: target) }

        it 'returns matched pipelines' do
          is_expected.to eq([pipeline])
        end
      end
    end

    context 'when scope is finished' do
      let(:params) { { scope: 'finished' } }
      let_it_be(:pipelines) do
        [create(:ci_pipeline, project: project, status: 'success'),
          create(:ci_pipeline, project: project, status: 'failed'),
          create(:ci_pipeline, project: project, status: 'canceled')]
      end

      it 'returns matched pipelines' do
        is_expected.to match_array(pipelines)
      end
    end

    context 'when scope is branches or tags' do
      let_it_be(:pipeline_branches1) { create_list(:ci_pipeline, 2, project: project) }
      let_it_be(:pipeline_branch2) { create(:ci_pipeline, project: project, ref: '2-mb-file') }
      let_it_be(:pipeline_tag1) { create(:ci_pipeline, :tag, project: project, ref: 'v1.0.0') }
      let_it_be(:pipeline_tag2) { create(:ci_pipeline, :tag, project: project, ref: 'v1.1.1') }
      let_it_be(:pipeline_tag2_branch) do
        project.repository.add_branch(create(:user), 'v1.1.1', 'master')
        create(:ci_pipeline, project: project, ref: 'v1.1.1')
      end

      context 'when scope is branches' do
        let(:params) { { scope: 'branches' } }

        context 'when project has no branches' do
          let(:project) { empty_project }

          it 'returns empty result' do
            is_expected.to be_empty
          end
        end

        context 'when project has child pipelines' do
          let_it_be(:child_pipeline) { create(:ci_pipeline, project: project, ref: pipeline_branch2.ref, source: :parent_pipeline) }

          let_it_be(:pipeline_source) do
            create(:ci_sources_pipeline, pipeline: child_pipeline, source_pipeline: pipeline_branch2)
          end

          it 'filters out child pipelines and shows only the parent pipelines' do
            is_expected.to match_array([pipeline_branches1.last, pipeline_branch2, pipeline_tag2_branch])
          end
        end

        it 'returns matched pipelines' do
          is_expected.to match_array([pipeline_branches1.last, pipeline_branch2, pipeline_tag2_branch])
        end
      end

      context 'when scope is tags' do
        let(:params) { { scope: 'tags' } }

        context 'when project has no tags' do
          let(:project) { empty_project }

          it 'returns empty result' do
            is_expected.to be_empty
          end
        end

        context 'when project has child pipelines' do
          let_it_be(:child_pipeline) { create(:ci_pipeline, :tag, project: project, source: :parent_pipeline, ref: 'v1.0.0') }

          let_it_be(:pipeline_source) do
            create(:ci_sources_pipeline, pipeline: child_pipeline, source_pipeline: pipeline_tag1)
          end

          it 'filters out child pipelines and shows only the parents by default' do
            is_expected.to match_array([pipeline_tag1, pipeline_tag2])
          end
        end

        it 'returns matched pipelines' do
          is_expected.to match_array([pipeline_tag1, pipeline_tag2])
        end
      end
    end

    context 'when project has child pipelines' do
      let_it_be(:parent_pipeline) { create(:ci_pipeline, project: project) }
      let_it_be(:child_pipeline) { create(:ci_pipeline, project: project, source: :parent_pipeline) }

      let_it_be(:pipeline_source) do
        create(:ci_sources_pipeline, pipeline: child_pipeline, source_pipeline: parent_pipeline)
      end

      it 'filters out child pipelines and shows only the parents by default' do
        is_expected.to eq([parent_pipeline])
      end

      context 'when source is parent_pipeline' do
        let(:params) { { source: 'parent_pipeline' } }

        it 'does not filter out child pipelines' do
          is_expected.to eq([child_pipeline])
        end
      end
    end

    Ci::HasStatus::AVAILABLE_STATUSES.each do |target|
      context "when status is #{target}" do
        let(:params) { { status: target } }
        let_it_be(:pipeline) { create(:ci_pipeline, project: project, status: target) }

        before_all do
          exception_status = Ci::HasStatus::AVAILABLE_STATUSES - [target]
          create(:ci_pipeline, project: project, status: exception_status.first)
        end

        it 'returns matched pipelines' do
          is_expected.to eq([pipeline])
        end
      end
    end

    context 'when ref is specified' do
      let_it_be(:pipeline) { create(:ci_pipeline, project: project) }

      context 'when ref exists' do
        let(:params) { { ref: 'master' } }

        it 'returns matched pipelines' do
          is_expected.to eq([pipeline])
        end
      end

      context 'when ref does not exist' do
        let(:params) { { ref: 'invalid-ref' } }

        it 'returns empty' do
          is_expected.to be_empty
        end
      end

      context 'when ref exists as a virtual ref' do
        let_it_be(:merge_request) do
          create(:merge_request, source_project: project, source_branch: 'my-mr-branch-ref', target_branch: 'master')
        end

        let(:params) { { ref: merge_request.source_branch } }

        it 'returns empty' do
          is_expected.to be_empty
        end

        context 'when pipeline on merge request with matching source branch exists' do
          let_it_be(:pipeline) do
            create(:ci_pipeline, project: project, ref: "refs/#{Repository::REF_MERGE_REQUEST}/#{merge_request.iid}/head")
          end

          it 'returns matched pipeline' do
            is_expected.to contain_exactly(pipeline)
          end

          context 'when source does not include merge_request_event' do
            let(:params) do
              {
                ref: merge_request.source_branch,
                source: Ci::Pipeline.sources.keys.excluding('merge_request_event')
              }
            end

            it 'returns empty' do
              is_expected.to be_empty
            end
          end
        end
      end
    end

    context 'when username is specified' do
      let_it_be(:user) { create(:user) }
      let_it_be(:pipeline) { create(:ci_pipeline, project: project, user: user) }

      context 'when username exists' do
        let(:params) { { username: user.username } }

        it 'returns matched pipelines' do
          is_expected.to eq([pipeline])
        end
      end

      context 'when username does not exist' do
        let(:params) { { username: 'invalid-username' } }

        it 'returns empty' do
          is_expected.to be_empty
        end
      end
    end

    context 'when yaml_errors is specified' do
      let_it_be(:pipeline1) { create(:ci_pipeline, project: project, yaml_errors: 'Syntax error') }
      let_it_be(:pipeline2) { create(:ci_pipeline, project: project) }

      context 'when yaml_errors is true' do
        let(:params) { { yaml_errors: true } }

        it 'returns matched pipelines' do
          is_expected.to eq([pipeline1])
        end
      end

      context 'when yaml_errors is false' do
        let(:params) { { yaml_errors: false } }

        it 'returns matched pipelines' do
          is_expected.to eq([pipeline2])
        end
      end

      context 'when yaml_errors is invalid' do
        let(:params) { { yaml_errors: "invalid-yaml_errors" } }

        it 'returns all pipelines' do
          is_expected.to match_array([pipeline1, pipeline2])
        end
      end
    end

    context 'when updated_at filters are specified' do
      let_it_be(:pipeline1) { create(:ci_pipeline, project: project, updated_at: 2.days.ago) }
      let_it_be(:pipeline2) { create(:ci_pipeline, project: project, updated_at: 4.days.ago) }
      let_it_be(:pipeline3) { create(:ci_pipeline, project: project, updated_at: 1.hour.ago) }

      context 'when both filters are specified' do
        let(:params) { { updated_before: 1.day.ago, updated_after: 3.days.ago } }

        it 'returns pipelines with matched updated_at' do
          is_expected.to match_array([pipeline1])
        end
      end

      context 'when only updated_before is specified' do
        let(:params) { { updated_before: 1.day.ago } }

        it 'returns pipelines with matched updated_at' do
          is_expected.to match_array([pipeline1, pipeline2])
        end
      end

      context 'when only updated_after is specified' do
        let(:params) { { updated_after: 1.day.ago } }

        it 'returns pipelines with matched updated_at' do
          is_expected.to match_array([pipeline3])
        end
      end
    end

    context 'when created_at filters are specified' do
      let_it_be(:pipeline1) { create(:ci_pipeline, project: project, created_at: 2.days.ago) }
      let_it_be(:pipeline2) { create(:ci_pipeline, project: project, created_at: 4.days.ago) }
      let_it_be(:pipeline3) { create(:ci_pipeline, project: project, created_at: 1.hour.ago) }

      context 'when both filters are specified' do
        let(:params) { { created_before: 1.day.ago, created_after: 3.days.ago } }

        it 'returns pipelines with matched created_at' do
          is_expected.to match_array([pipeline1])
        end
      end

      context 'when only created_before is specified' do
        let(:params) { { created_before: 1.day.ago } }

        it 'returns pipelines with matched created_at' do
          is_expected.to match_array([pipeline1, pipeline2])
        end
      end

      context 'when only created_after is specified' do
        let(:params) { { created_after: 1.day.ago } }

        it 'returns pipelines with matched created_at' do
          is_expected.to match_array([pipeline3])
        end
      end
    end

    context 'when ids filter is specified' do
      let(:params) { { ids: pipeline1.id } }
      let_it_be(:pipeline1) { create(:ci_pipeline, project: project) }
      let_it_be(:pipeline2) { create(:ci_pipeline, project: project) }
      let_it_be(:pipeline3) { create(:ci_pipeline, project: project, source: :parent_pipeline) }

      it 'returns matches pipelines' do
        is_expected.to match_array([pipeline1])
      end

      context 'when a child pipeline id is included' do
        let(:params) { { ids: [pipeline1.id, pipeline3.id] } }

        it 'does not filter out child pipelines' do
          is_expected.to match_array([pipeline1, pipeline3])
        end
      end
    end

    context 'when iids filter is specified' do
      let(:params) { { iids: [pipeline1.iid, pipeline3.iid] } }
      let_it_be(:pipeline1) { create(:ci_pipeline, project: project) }
      let_it_be(:pipeline2) { create(:ci_pipeline, project: project) }
      let_it_be(:pipeline3) { create(:ci_pipeline, project: project, source: :parent_pipeline) }

      it 'returns matches pipelines' do
        is_expected.to match_array([pipeline1, pipeline3])
      end

      it 'does not filter out child pipelines' do
        is_expected.to include(pipeline3)
      end
    end

    context 'when pipeline_schedule filter is specified' do
      let_it_be(:schedule) { create(:ci_pipeline_schedule, project: project) }
      let_it_be(:pipeline) { create(:ci_pipeline, project: project, pipeline_schedule: schedule) }
      let_it_be(:_) { create(:ci_pipeline, project: project) }

      let(:params) { { pipeline_schedules: [schedule] } }

      it 'returns pipeline created by schedule' do
        is_expected.to match_array([pipeline])
      end
    end

    context 'when sha is specified' do
      let_it_be(:pipeline) { create(:ci_pipeline, project: project, sha: '97de212e80737a608d939f648d959671fb0a0142') }

      context 'when sha exists' do
        let(:params) { { sha: '97de212e80737a608d939f648d959671fb0a0142' } }

        it 'returns matched pipelines' do
          is_expected.to eq([pipeline])
        end
      end

      context 'when sha does not exist' do
        let(:params) { { sha: 'invalid-sha' } }

        it 'returns empty' do
          is_expected.to be_empty
        end
      end
    end

    context 'when the project has limited access to pipelines' do
      let_it_be(:current_user) { create(:user) }
      let_it_be(:project) { create(:project, :private, :repository) }
      let_it_be(:pipelines) { create_list(:ci_pipeline, 2, project: project) }

      context 'when the user has access' do
        before_all do
          project.add_developer(current_user)
        end

        it 'is expected to return pipelines' do
          is_expected.to match_array(pipelines)
        end
      end

      context 'the user is not allowed to read pipelines' do
        it 'returns empty' do
          is_expected.to be_empty
        end
      end
    end

    context 'when source is specified' do
      let(:params) { { source: 'web' } }
      let_it_be(:web_pipeline) { create(:ci_pipeline, project: project, source: 'web') }
      let_it_be(:push_pipeline) { create(:ci_pipeline, project: project, source: 'push') }
      let_it_be(:api_pipeline) { create(:ci_pipeline, project: project, source: 'api') }

      it 'returns only the matched pipeline' do
        is_expected.to eq([web_pipeline])
      end
    end

    context 'when name is specified' do
      let_it_be(:pipeline) { create(:ci_pipeline, project: project, name: 'Build pipeline') }
      let_it_be(:pipeline_other) { create(:ci_pipeline, project: project, name: 'Some other pipeline') }

      let(:params) { { name: 'Build pipeline' } }

      it 'performs exact compare' do
        is_expected.to contain_exactly(pipeline)
      end

      it 'supports a bounded count without a username' do
        expect(execute.page.total_count_with_limit(:all, limit: 1)).to eq(1)
      end

      it 'uses the metadata lookup' do
        expect(execute.to_sql).to include('INNER JOIN LATERAL')
      end

      context 'when the feature flag is enabled for another project' do
        before do
          stub_feature_flags(pipeline_name_filter: empty_project)
        end

        it 'uses the original lookup for this project', :aggregate_failures do
          expect(execute.to_sql).not_to include('INNER JOIN LATERAL')
          expect(execute).to contain_exactly(pipeline)
        end
      end

      context 'when a selective filter is also specified' do
        let_it_be(:push_pipeline) do
          create(:ci_pipeline, project: project, name: 'Push build', source: 'push', ref: 'feature')
        end

        where(selective_params: [
          { source: 'push' },
          { ref: 'feature' }
        ])

        with_them do
          let(:params) { { name: 'Push build', **selective_params } }

          it 'uses the original lookup and keeps the filter', :aggregate_failures do
            expect(execute.to_sql).not_to include('INNER JOIN LATERAL')
            expect(execute).to contain_exactly(push_pipeline)
          end
        end

        context 'when filtering by sha' do
          let(:params) { { name: 'Push build', sha: push_pipeline.sha } }

          it 'uses the original lookup and keeps the filter', :aggregate_failures do
            expect(execute.to_sql).not_to include('INNER JOIN LATERAL')
            expect(execute).to contain_exactly(push_pipeline)
          end
        end

        context 'when the source filter matches nothing' do
          let(:params) { { name: 'Push build', source: 'schedule' } }

          it 'returns empty' do
            is_expected.to be_empty
          end
        end

        context 'when an unmeasured scope is also specified' do
          let(:params) { { name: 'Push build', scope: 'pending' } }

          it 'uses the original lookup and keeps the filter', :aggregate_failures do
            expect(execute.to_sql).not_to include('INNER JOIN LATERAL')
            expect(execute).to contain_exactly(push_pipeline)
          end
        end

        context 'when a running scope is also specified' do
          let(:params) { { name: 'Push build', scope: 'running' } }

          it 'uses the original lookup and returns no pipelines', :aggregate_failures do
            expect(execute.to_sql).not_to include('INNER JOIN LATERAL')
            expect(execute).to be_empty
          end
        end
      end

      context 'when a status filter is also specified' do
        let_it_be(:running_pipeline) do
          create(:ci_pipeline, :running, project: project, name: 'Build pipeline')
        end

        where(:status) { %w[running pending failed canceled] }

        with_them do
          let(:params) { { name: 'Build pipeline', status: status } }

          it 'uses the original lookup' do
            expect(execute.to_sql).not_to include('INNER JOIN LATERAL')
          end
        end

        it 'keeps the status filter result on the original lookup', :aggregate_failures do
          status_params = { name: 'Build pipeline', status: 'running' }
          status_finder = described_class.new(project, current_user, status_params)

          expect(status_finder.execute.to_sql).not_to include('INNER JOIN LATERAL')
          expect(status_finder.execute).to contain_exactly(running_pipeline)
        end
      end

      context 'when name does not exist' do
        let(:params) { { name: 'absent-name' } }

        it 'returns empty' do
          is_expected.to be_empty
        end
      end

      context 'when username is also specified' do
        let_it_be(:user) { create(:user) }
        let_it_be(:matching_pipeline) do
          create(:ci_pipeline, :success, project: project, user: user, name: 'Build pipeline', ref: 'master',
            source: 'web')
        end

        let_it_be(:failed_pipeline) do
          create(:ci_pipeline, :failed, project: project, user: user, name: 'Build pipeline', ref: 'feature',
            source: 'push')
        end

        let(:params) { super().merge(username: user.username) }

        it 'returns matching pipelines for the selected user' do
          expect(execute).to eq([failed_pipeline, matching_pipeline])
        end

        it 'retains the other filters on the metadata lookup', :aggregate_failures do
          params.merge!(status: 'success', scope: 'finished')

          expect(execute.to_sql).to include('INNER JOIN LATERAL')
          expect(execute).to contain_exactly(matching_pipeline)
        end

        it 'retains requested ordering' do
          params.merge!(order_by: 'ref', sort: 'desc')

          expect(execute).to eq([matching_pipeline, failed_pipeline])
        end

        context 'when the feature flag is disabled' do
          before do
            stub_feature_flags(pipeline_name_filter: false)
          end

          it 'uses the original lookup and retains the filters', :aggregate_failures do
            params.merge!(status: 'success', ref: 'master', source: 'web')

            expect(execute.to_sql).not_to include('INNER JOIN LATERAL')
            expect(execute).to contain_exactly(matching_pipeline)
          end
        end

        context 'when the username does not exist' do
          let(:params) { super().merge(username: 'invalid-username') }

          it 'returns no pipelines' do
            expect(execute).to be_empty
          end
        end

        context 'when scope is branches or tags' do
          using RSpec::Parameterized::TableSyntax

          where(:scope, :ref, :tag) do
            'branches' | 'master' | false
            'tags' | 'v1.0.0' | true
          end

          let(:params) { super().merge(scope: scope, ref: ref) }

          with_them do
            before do
              create(:ci_pipeline, project: project, user: user, name: 'Build pipeline', ref: ref, tag: tag)
              create(:ci_pipeline, project: project, user: user, ref: ref, tag: tag)
            end

            it 'excludes the lookup and filters the latest pipeline per ref before applying the name',
              :aggregate_failures do
              expect(execute.to_sql).not_to include('INNER JOIN LATERAL')
              expect(execute).to be_empty
            end

            it 'excludes the lookup when no ref filter is given' do
              scope_only_params = { name: 'Build pipeline', username: user.username, scope: scope }
              scope_only = described_class.new(project, current_user, scope_only_params)

              expect(scope_only.execute.to_sql).not_to include('INNER JOIN LATERAL')
            end
          end
        end
      end
    end

    describe 'ordering' do
      using RSpec::Parameterized::TableSyntax

      let(:params) { { order_by: order_by, sort: sort } }

      let_it_be(:pipeline_1) { create(:ci_pipeline, :scheduled, project: project, iid: 11, ref: 'master', created_at: Time.now, updated_at: Time.now, user: create(:user)) }
      let_it_be(:pipeline_2) { create(:ci_pipeline, :created, project: project, iid: 12, ref: 'feature', created_at: 1.day.ago, updated_at: 2.hours.ago, user: create(:user)) }
      let_it_be(:pipeline_3) { create(:ci_pipeline, :success, project: project, iid: 8, ref: 'patch', created_at: 2.days.ago, updated_at: 1.hour.ago, user: create(:user)) }

      where(:order_by, :sort, :ordered_pipelines) do
        'id'         | 'asc'  | [:pipeline_1, :pipeline_2, :pipeline_3]
        'id'         | 'desc' | [:pipeline_3, :pipeline_2, :pipeline_1]
        'ref'        | 'asc'  | [:pipeline_2, :pipeline_1, :pipeline_3]
        'ref'        | 'desc' | [:pipeline_3, :pipeline_1, :pipeline_2]
        'status'     | 'asc'  | [:pipeline_2, :pipeline_1, :pipeline_3]
        'status'     | 'desc' | [:pipeline_3, :pipeline_1, :pipeline_2]
        'updated_at' | 'asc'  | [:pipeline_2, :pipeline_3, :pipeline_1]
        'updated_at' | 'desc' | [:pipeline_1, :pipeline_3, :pipeline_2]
        'user_id'    | 'asc'  | [:pipeline_1, :pipeline_2, :pipeline_3]
        'user_id'    | 'desc' | [:pipeline_3, :pipeline_2, :pipeline_1]
        'invalid'    | 'asc'  | [:pipeline_1, :pipeline_2, :pipeline_3]
        'id'         | 'err'  | [:pipeline_3, :pipeline_2, :pipeline_1]
      end

      with_them do
        it 'returns the pipelines ordered' do
          expect(execute).to eq(ordered_pipelines.map { |name| public_send(name) })
        end
      end
    end

    describe 'merge_request_event_first ordering' do
      let_it_be(:push_pipeline_old) { create(:ci_pipeline, project: project, source: :push) }
      let_it_be(:mr_pipeline_old)   { create(:ci_pipeline, project: project, source: :merge_request_event) }
      let_it_be(:push_pipeline_new) { create(:ci_pipeline, project: project, source: :push) }
      let_it_be(:mr_pipeline_new)   { create(:ci_pipeline, project: project, source: :merge_request_event) }

      context 'when merge_request_event_first is true' do
        let(:params) { { merge_request_event_first: true } }

        it 'returns merge_request_event pipelines first, then others, each ordered by id desc' do
          expect(execute).to eq([mr_pipeline_new, mr_pipeline_old, push_pipeline_new, push_pipeline_old])
        end

        context 'when order_by is provided' do
          let(:params) { { merge_request_event_first: true, order_by: 'id', sort: 'asc' } }

          it 'applies the secondary order within each source bucket' do
            expect(execute).to eq([mr_pipeline_old, mr_pipeline_new, push_pipeline_old, push_pipeline_new])
          end
        end
      end

      context 'when merge_request_event_first is false or absent' do
        let(:params) { {} }

        it 'falls back to the default id desc ordering' do
          expect(execute).to eq([mr_pipeline_new, push_pipeline_new, mr_pipeline_old, push_pipeline_old])
        end
      end
    end
  end
end
