# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::MergeRequests, :aggregate_failures, feature_category: :source_code_management do
  include_context 'with merge requests API setup'

  shared_examples 'merge requests list caching' do
    let(:params) { {} }

    before do
      get api(endpoint_path), params: params
    end

    context 'when it is cached' do
      it_behaves_like 'a cached MergeRequest api request'
    end

    context 'when it is not cached' do
      context 'when the status changes' do
        before do
          merge_request.mark_as_unchecked!
        end

        it_behaves_like 'a non-cached MergeRequest api request', 1
      end

      context 'when the label changes' do
        before do
          merge_request.labels << create(:label, project: merge_request.project)
        end

        it_behaves_like 'a non-cached MergeRequest api request', 1
      end

      context 'when "with_labels_details" parameter is provided' do
        let(:params) { { with_labels_details: true } }

        it_behaves_like 'a non-cached MergeRequest api request', 4
      end

      context 'when the assignees change' do
        before do
          merge_request.assignees << create(:user)
        end

        it_behaves_like 'a non-cached MergeRequest api request', 1
      end

      context 'when the reviewers change' do
        before do
          merge_request.reviewers << create(:user)
        end

        it_behaves_like 'a non-cached MergeRequest api request', 1
      end

      context 'when another user requests' do
        before do
          sign_in(user2)
        end

        it_behaves_like 'a non-cached MergeRequest api request', 4
      end
    end
  end

  shared_examples 'merge requests list reusing ListRefs branch heads' do
    def find_commit_calls
      count = 0
      allow(Gitlab::GitalyClient).to receive(:call).and_wrap_original do |method, *args, **kwargs, &block|
        count += 1 if args[2] == :find_commit
        method.call(*args, **kwargs, &block)
      end

      # with_labels_details skips the response cache, so every request serializes
      get api(endpoint_path, user), params: { with_labels_details: true }
      count
    end

    it 'reads source branch heads from ListRefs instead of FindCommit' do
      # Without batched branch heads the conflict check reads each source branch head with FindCommit
      allow(MergeRequests::Mergeability::DetailedMergeStatusService).to receive(:new)
        .and_wrap_original { |method, **kwargs| method.call(**kwargs.merge(batched_branch_heads: false)) }
      calls_without_reuse = find_commit_calls
      statuses = json_response.to_h { |mr| [mr['id'], mr['detailed_merge_status']] }

      allow(MergeRequests::Mergeability::DetailedMergeStatusService).to receive(:new).and_call_original

      expect(find_commit_calls).to be < calls_without_reuse
      expect(json_response.to_h { |mr| [mr['id'], mr['detailed_merge_status']] }).to eq(statuses)
    end
  end

  shared_examples 'merge requests list' do
    it_behaves_like 'issuable API rate-limited search' do
      let(:url) { endpoint_path }
      let(:issuable) { merge_request }
    end

    context 'when unauthenticated' do
      it 'returns merge requests for public projects' do
        get api(endpoint_path)

        expect_successful_response_with_paginated_array
      end
    end

    context 'when authenticated' do
      it 'avoids N+1 queries', :request_store, :use_sql_query_cache do
        create_list(:merge_request, 3, :unique_branches, state: 'closed', milestone: milestone1, author: user, assignees: [user], source_project: project, created_at: base_time)

        control = ActiveRecord::QueryRecorder.new(skip_cached: false) do
          get api(endpoint_path, user)
        end

        create_list(:merge_request, 2, :unique_branches, state: 'closed', milestone: milestone1, author: user, assignees: [user], source_project: project, created_at: base_time)
        merge_request = create(:merge_request, milestone: milestone1, author: user, assignees: [user], source_project: project, target_project: project, title: 'Test 4', created_at: base_time)

        merge_request.metrics.update!(
          merged_by: user,
          latest_closed_by: user,
          latest_closed_at: 1.hour.ago,
          merged_at: 2.hours.ago
        )

        expect do
          get api(endpoint_path, user)
        end.not_to exceed_query_limit(control).allow_skip_cache_inconsistency.with_threshold(allowed_query_threshold)
      end

      context 'with unresolved threads' do
        let(:mr_entity) { json_response.find { |mr| mr['id'] == merge_request.id } }

        def unresolved_notes_queries
          ActiveRecord::QueryRecorder.new { get api(endpoint_path, user) }
            .log.grep(/FROM "notes" WHERE .*"notes"."resolved_at" IS NULL/)
        end

        before do
          create(:discussion_note_on_merge_request, noteable: merge_request, project: merge_request.project)
        end

        context 'when the project does not require resolved threads' do
          it 'does not load unresolved notes' do
            expect(unresolved_notes_queries).to be_empty
            expect(mr_entity['blocking_discussions_resolved']).to be(true)
          end

          context 'when skip_unneeded_unresolved_notes_preload is disabled' do
            before do
              stub_feature_flags(skip_unneeded_unresolved_notes_preload: false)
            end

            it 'loads unresolved notes' do
              expect(unresolved_notes_queries).to be_present
            end
          end
        end

        context 'when the project requires resolved threads' do
          before do
            Project.find(merge_request.target_project_id).update!(only_allow_merge_if_all_discussions_are_resolved: true)
          end

          it 'loads unresolved notes in one query' do
            other_merge_request = create(:merge_request, :unique_branches, source_project: merge_request.target_project)
            create(:discussion_note_on_merge_request, noteable: other_merge_request, project: other_merge_request.project)

            expect(unresolved_notes_queries.size).to eq(1)
            expect(mr_entity['blocking_discussions_resolved']).to be(false)
          end
        end
      end

      context 'when merge requests are merged' do
        it 'avoids N+1 queries', :request_store, :use_sql_query_cache do
          create_list(:merge_request, 3, state: :merged, source_project: project, target_project: project, merge_user: create(:user))

          control = ActiveRecord::QueryRecorder.new(skip_cached: false) do
            get api(endpoint_path, user)
          end

          create_list(:merge_request, 3, state: :merged, source_project: project, target_project: project, merge_user: create(:user))

          expect do
            get api(endpoint_path, user)
          end.not_to exceed_query_limit(control).allow_skip_cache_inconsistency.with_threshold(allowed_query_threshold)
        end
      end

      context 'when merge request is unchecked' do
        let(:check_service_class) { MergeRequests::MergeabilityCheckService }
        let(:mr_entity) { json_response.find { |mr| mr['id'] == merge_request.id } }
        let_it_be_with_reload(:merge_request) { create(:merge_request, :simple, author: user, source_project: project, title: "Test") }

        before do
          merge_request.mark_as_unchecked!
        end

        context 'with a developer+ role' do
          before do
            project.add_developer(user2)
          end

          context 'with merge status recheck protection' do
            it 'checks mergeability asynchronously in batch', :sidekiq_inline do
              get(api(endpoint_path, user2), params: { with_merge_status_recheck: true })

              expect_successful_response_with_paginated_array

              expect(merge_request.reload.merge_status).to eq('can_be_merged')
            end
          end

          context 'without merge status recheck protection' do
            it 'does not enqueue a merge status recheck' do
              expect(check_service_class).not_to receive(:new)

              get api(endpoint_path, user2)

              expect_successful_response_with_paginated_array
              expect(mr_entity['merge_status']).to eq('unchecked')
            end
          end

          context 'with view=simple' do
            it 'does not check mergeability', :sidekiq_inline do
              expect(check_service_class).not_to receive(:new)

              get(api(endpoint_path, user2), params: { view: 'simple' })

              expect_successful_response_with_paginated_array
              expect(merge_request.reload.merge_status).to eq('unchecked')
            end
          end
        end

        context 'with a reporter role' do
          context 'with merge status recheck protection' do
            it 'does not check mergeability', :sidekiq_inline do
              expect(check_service_class).not_to receive(:new)

              get(api(endpoint_path, user2), params: { with_merge_status_recheck: true })

              expect_successful_response_with_paginated_array
              expect(mr_entity['merge_status']).to eq('unchecked')
              expect(merge_request.reload.merge_status).to eq('unchecked')
            end
          end
        end
      end

      context 'with labels' do
        include_context 'with labels'

        it 'returns an array of all merge_requests' do
          get api(endpoint_path, user)

          expect_paginated_array_response(
            [
              merge_request_merged.id,
              merge_request_locked.id,
              merge_request_closed.id,
              merge_request.id
            ])

          expect(json_response.last['title']).to eq(merge_request.title)
          expect(json_response.last).to have_key('web_url')
          expect(json_response.last['sha']).to eq(merge_request.diff_head_sha)
          expect(json_response.last['merge_commit_sha']).to be_nil
          expect(json_response.last['merge_commit_sha']).to eq(merge_request.merge_commit_sha)
          expect(json_response.last['downvotes']).to eq(0)
          expect(json_response.last['upvotes']).to eq(0)
          expect(json_response.last['labels']).to eq([label2.title, label.title])
          expect(json_response.first['title']).to eq(merge_request_merged.title)
          expect(json_response.first['sha']).to eq(merge_request_merged.diff_head_sha)
          expect(json_response.first['merge_commit_sha']).not_to be_nil
          expect(json_response.first['merge_commit_sha']).to eq(merge_request_merged.merge_commit_sha)
        end

        context 'with labels_details' do
          it 'returns labels with details' do
            path = endpoint_path + "?with_labels_details=true"

            get api(path, user)

            expect_successful_response_with_paginated_array
            expect(json_response.last['labels'].pluck('name')).to eq([label2.title, label.title])
            expect(json_response.last['labels'].first).to match_schema('/public_api/v4/label_basic')
          end

          it 'avoids N+1 queries', quarantine: 'https://gitlab.com/gitlab-org/quality/test-failure-issues/-/issues/9318' do
            path = endpoint_path + "?with_labels_details=true"

            control = ActiveRecord::QueryRecorder.new do
              get api(path, user)
            end

            mr = create(:merge_request)
            create(:label_link, label: label, target: mr)
            create(:label_link, label: label2, target: mr)

            expect do
              get api(path, user)
            end.not_to exceed_query_limit(control)
          end
        end
      end

      context 'when DB timeouts occur' do
        it 'returns a :request_timeout status' do
          allow(MergeRequestsFinder).to receive(:new).and_raise(ActiveRecord::QueryCanceled)

          path = endpoint_path + '?view=simple'
          get api(path, user)

          expect(response).to have_gitlab_http_status(:request_timeout)
        end
      end

      it 'returns an array of all merge_requests using simple mode' do
        path = endpoint_path + '?view=simple'

        get api(path, user)

        expect_paginated_array_response(
          [
            merge_request_merged.id,
            merge_request_locked.id,
            merge_request_closed.id,
            merge_request.id
          ])
        expect(json_response.last.keys).to match_array(%w[id iid title web_url created_at description project_id state updated_at])
        expect(json_response.last['iid']).to eq(merge_request.iid)
        expect(json_response.last['title']).to eq(merge_request.title)
        expect(json_response.last).to have_key('web_url')
        expect(json_response.first['iid']).to eq(merge_request_merged.iid)
        expect(json_response.first['title']).to eq(merge_request_merged.title)
        expect(json_response.first).to have_key('web_url')
      end

      it 'matches V4 response schema' do
        get api(endpoint_path, user)

        expect(response).to have_gitlab_http_status(:ok)
        expect(response).to match_response_schema('public_api/v4/merge_requests')
      end
    end
  end

  # The filter logic is the same for the project and group endpoints, so only the project endpoint runs these.
  # The group endpoint compares its results with the project endpoint to cover its own finder query.
  shared_examples 'merge requests list filters' do
    context 'when authenticated' do
      it 'returns an array of open merge_requests' do
        path = endpoint_path + '?state=opened'

        get api(path, user)

        expect_paginated_array_response([merge_request.id])
        expect(json_response.last['title']).to eq(merge_request.title)
      end

      it 'returns an array of closed merge_requests' do
        path = endpoint_path + '?state=closed'

        get api(path, user)

        expect_paginated_array_response([merge_request_closed.id])
        expect(json_response.first['title']).to eq(merge_request_closed.title)
      end

      it 'returns an array of merged merge_requests' do
        path = endpoint_path + '?state=merged'

        get api(path, user)

        expect_paginated_array_response([merge_request_merged.id])
        expect(json_response.first['title']).to eq(merge_request_merged.title)
      end

      it 'returns an empty array if milestone does not exist' do
        get api(endpoint_path, user), params: { milestone: 'foo' }

        expect_empty_array_response
      end

      it 'returns an array of merge requests matching state in milestone' do
        get api(endpoint_path, user), params: { milestone: '0.9', state: 'closed' }

        expect_paginated_array_response([merge_request_closed.id])
        expect(json_response.first['id']).to eq(merge_request_closed.id)
      end

      context 'with labels' do
        include_context 'with labels'

        it 'returns an array of labeled merge requests' do
          path = endpoint_path + "?labels=#{label.title}"

          get api(path, user)

          expect_successful_response_with_paginated_array
          expect(json_response.length).to eq(1)
          expect(json_response.first['labels']).to eq([label2.title, label.title])
        end

        it 'returns an array of labeled merge requests where all labels match' do
          path = endpoint_path + "?labels=#{label.title},foo,bar"

          get api(path, user)

          expect_empty_array_response
        end

        it 'returns an array of labeled merge requests where all labels match' do
          path = endpoint_path + "?labels[]=#{label.title}&labels[]=#{label2.title}"

          get api(path, user)

          expect_successful_response_with_paginated_array
          expect(json_response.length).to eq(1)
          expect(json_response.first['labels']).to eq([label2.title, label.title])
        end

        it 'returns an array of merge requests with any label when filtering by any label' do
          get api(endpoint_path, user), params: { labels: [" #{label.title} ", " #{label2.title} "] }

          expect_paginated_array_response([merge_request.id])
          expect(json_response.first['labels']).to eq([label2.title, label.title])
          expect(json_response.first['id']).to eq(merge_request.id)
        end

        it 'returns an array of merge requests with any label when filtering by any label' do
          get api(endpoint_path, user), params: { labels: ["#{label.title} , #{label2.title}"] }

          expect_paginated_array_response([merge_request.id])
          expect(json_response.first['labels']).to eq([label2.title, label.title])
          expect(json_response.first['id']).to eq(merge_request.id)
        end

        it 'returns an array of merge requests with any label when filtering by any label' do
          get api(endpoint_path, user), params: { labels: IssuableFinder::Params::FILTER_ANY }

          expect_paginated_array_response([merge_request.id])
          expect(json_response.first['id']).to eq(merge_request.id)
        end

        it 'returns an array of merge requests without a label when filtering by no label' do
          get api(endpoint_path, user), params: { labels: IssuableFinder::Params::FILTER_NONE }

          expect_response_contain_exactly(
            merge_request_merged.id, merge_request_locked.id, merge_request_closed.id
          )
        end
      end

      it 'returns an array of labeled merge requests that are merged for a milestone' do
        bug_label = create(:label, title: 'bug', color: '#FFAABB', project: project)

        mr1 = create(:merge_request, state: 'merged', source_project: project, target_project: project, milestone: milestone)
        mr2 = create(:merge_request, state: 'merged', source_project: project, target_project: project, milestone: milestone1)
        mr3 = create(:merge_request, state: 'closed', source_project: project, target_project: project, milestone: milestone1)
        _mr = create(:merge_request, state: 'merged', source_project: project, target_project: project, milestone: milestone1)

        create(:label_link, label: bug_label, target: mr1)
        create(:label_link, label: bug_label, target: mr2)
        create(:label_link, label: bug_label, target: mr3)

        path = endpoint_path + "?labels=#{bug_label.title}&milestone=#{milestone1.title}&state=merged"

        get api(path, user)

        expect_response_contain_exactly(mr2.id)
      end

      context 'with ordering' do
        context '2 merge requests with equal created_at' do
          it 'page breaks first page correctly' do
            get api("#{endpoint_path}?sort=desc&per_page=2", user)

            response_ids = json_response.map { |merge_request| merge_request['id'] }

            expect(response_ids).to contain_exactly(merge_request_merged.id, merge_request_locked.id)
          end

          it 'page breaks second page correctly' do
            get api("#{endpoint_path}?sort=desc&per_page=2&page=2", user)

            response_ids = json_response.map { |merge_request| merge_request['id'] }

            expect(response_ids).to contain_exactly(merge_request_closed.id, merge_request.id)
          end
        end

        it 'returns an array of merge_requests ordered by updated_at' do
          path = endpoint_path + '?order_by=updated_at'

          get api(path, user)

          expect_paginated_array_response(
            [
              merge_request.id,
              merge_request_locked.id,
              merge_request_merged.id,
              merge_request_closed.id
            ])
          response_dates = json_response.map { |merge_request| merge_request['updated_at'] }
          expect(response_dates).to eq(response_dates.sort.reverse)
        end

        it 'returns an array of merge_requests ordered by created_at' do
          path = endpoint_path + '?order_by=created_at&sort=asc'

          get api(path, user)

          expect_paginated_array_response(
            [
              merge_request.id,
              merge_request_closed.id,
              merge_request_locked.id,
              merge_request_merged.id
            ])
          response_dates = json_response.map { |merge_request| merge_request['created_at'] }
          expect(response_dates).to eq(response_dates.sort)
        end

        context 'returns an array of merge_requests ordered by title' do
          it 'asc when requested' do
            path = endpoint_path + '?order_by=title&sort=asc'

            get api(path, user)

            response_titles = json_response.map { |merge_request| merge_request['title'] }
            expect(response_titles).to eq(response_titles.sort)
          end

          it 'desc when requested' do
            path = endpoint_path + '?order_by=title&sort=desc'

            get api(path, user)

            response_titles = json_response.map { |merge_request| merge_request['title'] }
            expect(response_titles).to eq(response_titles.sort.reverse)
          end
        end
      end

      context 'NOT params' do
        let_it_be_with_reload(:milestone) { create(:milestone, title: '1.0.0', project: project) }
        let_it_be(:merge_request2) do
          create(
            :merge_request,
            :simple,
            milestone: milestone,
            author: user,
            assignees: [user],
            reviewers: [user2],
            source_project: project,
            target_project: project,
            source_branch: 'what',
            title: "What",
            created_at: base_time
          )
        end

        let_it_be(:merge_request_context_commit) { create(:merge_request_context_commit, merge_request: merge_request2, message: 'test') }

        before do
          create(:label_link, label: label, target: merge_request)
          create(:label_link, label: label2, target: merge_request2)
        end

        it 'returns merge requests without any of the labels given' do
          get api(endpoint_path, user), params: { not: { labels: ["#{label.title}, #{label2.title}"] } }

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response).to be_an(Array)
          expect(json_response.length).to eq(3)
          json_response.each do |mr|
            expect(mr['labels']).not_to include(label2.title, label.title)
          end
        end

        it 'returns merge requests without any of the milestones given' do
          get api(endpoint_path, user), params: { not: { milestone: milestone.title } }

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response).to be_an(Array)
          expect(json_response.length).to eq(4)
          json_response.each do |mr|
            expect(mr['milestone']).not_to eq(milestone.title)
          end
        end

        it 'returns merge requests without the author given' do
          get api(endpoint_path, user), params: { not: { author_id: user2.id } }

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response).to be_an(Array)
          expect(json_response.length).to eq(5)
          json_response.each do |mr|
            expect(mr['author']['id']).not_to eq(user2.id)
          end
        end

        it 'returns merge requests without the assignee given' do
          get api(endpoint_path, user), params: { not: { assignee_id: user2.id } }

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response).to be_an(Array)
          expect(json_response.length).to eq(5)
          json_response.each do |mr|
            expect(mr['assignee']['id']).not_to eq(user2.id)
          end
        end

        context 'filter by reviewer' do
          context 'with reviewer_id' do
            context 'with an id' do
              let(:params) { { not: { reviewer_id: user2.id } } }

              it 'returns merge requests that do not have the given reviewer' do
                get api(endpoint_path, user), params: { not: { reviewer_id: user2.id } }

                expect(response).to have_gitlab_http_status(:ok)
                expect(json_response).to be_an(Array)
                expect(json_response.length).to eq(4)
                expect(json_response.map { |mr| mr['id'] }).not_to include(merge_request2)
              end
            end

            context 'with Any' do
              let(:params) { { not: { reviewer_id: 'Any' } } }

              it 'returns a 400' do
                # Any is not supported for negated filter
                get api(endpoint_path, user), params: params

                expect(response).to have_gitlab_http_status(:bad_request)
                expect(json_response['error']).to eq('not[reviewer_id] is invalid')
              end
            end

            context 'with None' do
              let(:params) { { not: { reviewer_id: 'None' } } }

              it 'returns a 400' do
                # None is not supported for negated filter
                get api(endpoint_path, user), params: params

                expect(response).to have_gitlab_http_status(:bad_request)
                expect(json_response['error']).to eq('not[reviewer_id] is invalid')
              end
            end
          end

          context 'with reviewer_username' do
            let(:params) { { not: { reviewer_username: user2.username } } }

            it 'returns merge requests that do not have the given reviewer' do
              get api(endpoint_path, user), params: params

              expect(response).to have_gitlab_http_status(:ok)
              expect(json_response).to be_an(Array)
              expect(json_response.length).to eq(4)
              expect(json_response.map { |mr| mr['id'] }).not_to include(merge_request2)
            end
          end

          context 'when both reviewer_id and reviewer_username' do
            let(:params) { { not: { reviewer_id: user2.id, reviewer_username: user2.username } } }

            it 'returns a 400' do
              get api('/merge_requests', user), params: params

              expect(response).to have_gitlab_http_status(:bad_request)
              expect(json_response['error']).to eq('not[reviewer_id], not[reviewer_username] are mutually exclusive')
            end
          end
        end
      end

      context 'source_branch param' do
        it 'returns merge requests with the given source branch' do
          get api(endpoint_path, user), params: { source_branch: merge_request_closed.source_branch, state: 'all' }

          expect_response_contain_exactly(
            merge_request_merged.id, merge_request_locked.id, merge_request_closed.id
          )
        end
      end

      context 'target_branch param' do
        it 'returns merge requests with the given target branch' do
          get api(endpoint_path, user), params: { target_branch: merge_request_closed.target_branch, state: 'all' }

          expect_response_contain_exactly(
            merge_request_merged.id, merge_request_locked.id, merge_request_closed.id
          )
        end
      end
    end
  end

  RSpec.shared_examples 'a non-cached MergeRequest api request' do |call_count|
    it 'serializes merge request' do
      expect(API::Entities::MergeRequestBasic).to receive(:represent).exactly(call_count).times.and_call_original

      get api(endpoint_path)
    end
  end

  RSpec.shared_examples 'a cached MergeRequest api request' do
    it 'serializes merge request' do
      expect(API::Entities::MergeRequestBasic).not_to receive(:represent)

      get api(endpoint_path)
    end
  end

  describe 'route shadowing' do
    include GrapePathHelpers::NamedRouteMatcher

    it 'does not occur' do
      path = api_v4_projects_merge_requests_path(id: 1)
      expect(path).to eq('/api/v4/projects/1/merge_requests')

      path = api_v4_projects_merge_requests_path(id: 1, merge_request_iid: 3)
      expect(path).to eq('/api/v4/projects/1/merge_requests/3')
    end
  end

  describe 'GET /merge_requests' do
    include_context 'with merge requests'

    it_behaves_like 'merge requests list reusing ListRefs branch heads' do
      let(:endpoint_path) { '/merge_requests' }
    end

    context 'with bot authors' do
      let_it_be(:bot_author) { create(:user, :project_bot) }
      let_it_be(:bot_merge_request) do
        create(:merge_request, :simple, source_project: project, target_project: project, author: bot_author)
      end

      it 'includes bot status for human and bot authors' do
        get api('/merge_requests', user), params: { scope: 'all' }

        expect(response).to have_gitlab_http_status(:ok)
        expect(response).to match_response_schema('public_api/v4/merge_requests')
        expect(json_response).to include(
          a_hash_including('id' => merge_request.id, 'author' => a_hash_including('bot' => false)),
          a_hash_including('id' => bot_merge_request.id, 'author' => a_hash_including('bot' => true))
        )
      end

      it 'avoids N+1 queries when serializing bot authors', :request_store, :use_sql_query_cache do
        get api('/merge_requests', user), params: { scope: 'all' }

        control = ActiveRecord::QueryRecorder.new(skip_cached: false) do
          get api('/merge_requests', user), params: { scope: 'all' }
        end

        create_list(:merge_request, 3, :simple, :closed, source_project: project, target_project: project,
          author: create(:user, :service_account))

        expect do
          get api('/merge_requests', user), params: { scope: 'all' }
        end.not_to exceed_all_query_limit(control).with_threshold(allowed_query_threshold)
      end
    end

    it_behaves_like 'issuable API rate-limited search' do
      let(:url) { '/merge_requests' }
      let(:issuable) { merge_request }
    end

    context 'when unauthenticated' do
      it 'returns an array of all merge requests' do
        get api('/merge_requests'), params: { scope: 'all' }

        expect_response_contain_exactly(
          merge_request_merged.id, merge_request_locked.id,
          merge_request_closed.id, merge_request.id
        )
      end

      it "returns authentication error without any scope" do
        get api("/merge_requests")

        expect(response).to have_gitlab_http_status(:unauthorized)
      end

      it "returns authentication error when scope is assigned-to-me" do
        get api("/merge_requests"), params: { scope: 'assigned-to-me' }

        expect(response).to have_gitlab_http_status(:unauthorized)
      end

      it "returns authentication error when scope is assigned_to_me" do
        get api("/merge_requests"), params: { scope: 'assigned_to_me' }

        expect(response).to have_gitlab_http_status(:unauthorized)
      end

      it "returns authentication error when scope is reviews_for_me" do
        get api("/merge_requests"), params: { scope: 'reviews_for_me' }

        expect(response).to have_gitlab_http_status(:unauthorized)
      end

      it "returns authentication error when scope is created-by-me" do
        get api("/merge_requests"), params: { scope: 'created-by-me' }

        expect(response).to have_gitlab_http_status(:unauthorized)
      end
    end

    context 'when authenticated' do
      let_it_be(:project2, freeze: false) { create(:project, :public, :repository, namespace: user.namespace) }
      let_it_be(:merge_request2) { create(:merge_request, :simple, author: user, assignees: [user], source_project: project2, target_project: project2) }
      let_it_be(:user2, freeze: false) { create(:user) }

      it "returns an array of no merge_requests when wip=yes" do
        get api("/merge_requests", user), params: { wip: 'yes' }

        expect_empty_array_response
      end

      it "returns an array of no merge_requests when wip=no" do
        get api("/merge_requests", user), params: { wip: 'no' }

        expect_response_contain_exactly(
          merge_request_merged.id, merge_request2.id, merge_request_locked.id,
          merge_request_closed.id, merge_request.id
        )
      end

      context 'with draft parameter' do
        let_it_be(:draft_mr) { create(:merge_request, :draft_merge_request, author: user, source_project: project2, target_project: project2) }

        it 'returns only draft merge requests when draft=true' do
          get api('/merge_requests', user), params: { draft: true }

          expect_response_contain_exactly(draft_mr.id)
        end

        it 'returns only non-draft merge requests when draft=false' do
          get api('/merge_requests', user), params: { draft: false }

          expect_response_contain_exactly(
            merge_request_merged.id, merge_request2.id, merge_request_locked.id,
            merge_request_closed.id, merge_request.id
          )
        end

        it 'returns 400 when both draft and wip are specified' do
          get api('/merge_requests', user), params: { draft: true, wip: 'yes' }

          expect(response).to have_gitlab_http_status(:bad_request)
        end
      end

      it 'does not return unauthorized merge requests' do
        private_project = create(:project, :private)
        merge_request3 = create(:merge_request, :simple, source_project: private_project, target_project: private_project, source_branch: 'other-branch')

        get api('/merge_requests', user), params: { scope: :all }

        expect_response_contain_exactly(
          merge_request_merged.id, merge_request2.id, merge_request_locked.id,
          merge_request_closed.id, merge_request.id
        )
        expect(json_response.map { |mr| mr['id'] }).not_to include(merge_request3.id)
      end

      it 'returns an array of merge requests created by current user if no scope is given' do
        merge_request3 = create(:merge_request, :simple, author: user2, assignees: [user], source_project: project2, target_project: project2, source_branch: 'other-branch')

        get api('/merge_requests', user2)

        expect_response_contain_exactly(merge_request3.id)
      end

      context 'filter by author' do
        let_it_be_with_reload(:user3) { create(:user) }
        let_it_be_with_reload(:project) { create(:project, :public, :repository, creator: user3, namespace: user3.namespace, only_allow_merge_if_pipeline_succeeds: false) }
        let_it_be_with_reload(:merge_request3) do
          create(:merge_request, :simple, author: user3, assignees: [user3], source_project: project, target_project: project, source_branch: 'other-branch')
        end

        context 'when only `author_id` is passed' do
          it 'returns an array of merge requests authored by the given user' do
            get api('/merge_requests', user), params: {
              author_id: user3.id,
              scope: :all
            }

            expect_response_contain_exactly(merge_request3.id)
          end
        end

        context 'when only `author_username` is passed' do
          it 'returns an array of merge requests authored by the given user(by `author_username`)' do
            get api('/merge_requests', user), params: {
              author_username: user3.username,
              scope: :all
            }

            expect_response_contain_exactly(merge_request3.id)
          end
        end

        context 'when both `author_id` and `author_username` are passed' do
          it 'returns a 400' do
            get api('/merge_requests', user), params: {
              author_id: user.id,
              author_username: user2.username,
              scope: :all
            }

            expect(response).to have_gitlab_http_status(:bad_request)
            expect(json_response['error']).to eq(
              'author_id, author_username are mutually exclusive')
          end
        end
      end

      context 'filter by reviewer' do
        let_it_be(:review_requested_mr1, freeze: false) do
          create(:merge_request, :unique_branches, author: user, reviewers: [user2], source_project: project2, target_project: project2)
        end

        let_it_be(:review_requested_mr2) do
          create(:merge_request, :unique_branches, author: user2, reviewers: [user], source_project: project2, target_project: project2)
        end

        let(:params) { { scope: :all } }

        context 'with reviewer_id' do
          let(:params) { super().merge(reviewer_id: reviewer_id) }

          context 'with an id' do
            let(:reviewer_id) { user2.id }

            it 'returns review requested merge requests for the given user' do
              get api('/merge_requests', user), params: params

              expect_response_contain_exactly(review_requested_mr1.id)
            end
          end

          context 'with Any' do
            let(:reviewer_id) { 'Any' }

            it 'returns review requested merge requests for any user' do
              get api('/merge_requests', user), params: params

              expect_response_contain_exactly(review_requested_mr1.id, review_requested_mr2.id)
            end
          end

          context 'with None' do
            let(:reviewer_id) { 'None' }

            it 'returns merge requests that has no assigned reviewers' do
              get api('/merge_requests', user), params: params

              expect_response_contain_exactly(
                merge_request.id,
                merge_request_closed.id,
                merge_request_merged.id,
                merge_request_locked.id,
                merge_request2.id
              )
            end
          end
        end

        context 'with reviewer_username' do
          let(:params) { super().merge(reviewer_username: user2.username) }

          it 'returns review requested merge requests for the given user' do
            get api('/merge_requests', user), params: params

            expect_response_contain_exactly(review_requested_mr1.id)
          end
        end

        context 'with both reviewer_id and reviewer_username' do
          let(:params) { super().merge(reviewer_id: user2.id, reviewer_username: user2.username) }

          it 'returns a 400' do
            get api('/merge_requests', user), params: params

            expect(response).to have_gitlab_http_status(:bad_request)
            expect(json_response['error']).to eq('reviewer_id, reviewer_username are mutually exclusive')
          end
        end
      end

      context 'filter by merge_user' do
        let(:params) { { scope: :all } }

        context 'with merge_user_id' do
          let(:params) { super().merge(merge_user_id: user.id) }

          it 'returns merged merge requests for the given user' do
            get api('/merge_requests', user), params: params

            expect_response_contain_exactly(merge_request_merged.id)
          end
        end

        context 'with merge_user_username' do
          let(:params) { super().merge(merge_user_username: user.username) }

          it 'returns merged merge requests for the given user' do
            get api('/merge_requests', user), params: params

            expect_response_contain_exactly(merge_request_merged.id)
          end
        end

        context 'with both merge_user_id and merge_user_username' do
          let(:params) { super().merge(merge_user_id: user.id, merge_user_username: user.username) }

          it 'returns a 400' do
            get api('/merge_requests', user), params: params

            expect(response).to have_gitlab_http_status(:bad_request)
            expect(json_response['error']).to eq('merge_user_id, merge_user_username are mutually exclusive')
          end
        end
      end

      it 'returns an array of merge requests assigned to the given user' do
        merge_request3 = create(:merge_request, :simple, author: user, assignees: [user2], source_project: project2, target_project: project2, source_branch: 'other-branch')

        get api('/merge_requests', user), params: { assignee_id: user2.id, scope: :all }

        expect_response_contain_exactly(merge_request3.id)
      end

      it 'returns an array of merge requests with no assignee' do
        merge_request3 = create(:merge_request, :simple, author: user, source_project: project2, target_project: project2, source_branch: 'other-branch')

        get api('/merge_requests', user), params: { assignee_id: 'None', scope: :all }

        expect_response_contain_exactly(merge_request3.id)
      end

      it 'returns an array of merge requests with any assignee' do
        # This MR with no assignee should not be returned
        create(:merge_request, :simple, author: user, source_project: project2, target_project: project2, source_branch: 'other-branch')

        get api('/merge_requests', user), params: { assignee_id: 'Any', scope: :all }

        expect_response_contain_exactly(
          merge_request_merged.id, merge_request2.id, merge_request_locked.id,
          merge_request_closed.id, merge_request.id
        )
      end

      it 'returns an array of merge requests assigned to me' do
        merge_request3 = create(:merge_request, :simple, author: user, assignees: [user2], source_project: project2, target_project: project2, source_branch: 'other-branch')

        get api('/merge_requests', user2), params: { scope: 'assigned_to_me' }

        expect_response_contain_exactly(merge_request3.id)
      end

      it 'returns an array of merge requests assigned to me (kebab-case)' do
        merge_request3 = create(:merge_request, :simple, author: user, assignees: [user2], source_project: project2, target_project: project2, source_branch: 'other-branch')

        get api('/merge_requests', user2), params: { scope: 'assigned-to-me' }

        expect_response_contain_exactly(merge_request3.id)
      end

      it 'returns an array of merge requests created by me' do
        merge_request3 = create(:merge_request, :simple, author: user2, assignees: [user], source_project: project2, target_project: project2, source_branch: 'other-branch')

        get api('/merge_requests', user2), params: { scope: 'created_by_me' }

        expect_response_contain_exactly(merge_request3.id)
      end

      it 'returns an array of merge requests created by me (kebab-case)' do
        merge_request3 = create(:merge_request, :simple, author: user2, assignees: [user], source_project: project2, target_project: project2, source_branch: 'other-branch')

        get api('/merge_requests', user2), params: { scope: 'created-by-me' }

        expect_response_contain_exactly(merge_request3.id)
      end

      it 'returns an array of merge requests where I am a reviewer' do
        # Create a merge request where user2 is a reviewer
        merge_request3 = create(:merge_request, :simple, author: user, source_project: project2, target_project: project2, source_branch: 'other-branch')
        merge_request3.update!(reviewer_ids: [user2.id])

        # Create a merge request where someone else is a reviewer (should not be returned)
        merge_request4 = create(:merge_request, :simple, author: user, source_project: project2, target_project: project2, source_branch: 'another-branch')
        merge_request4.update!(reviewer_ids: [user.id])

        # Create a merge request with no reviewers (should not be returned)
        create(:merge_request, :simple, author: user, source_project: project2, target_project: project2, source_branch: 'no-reviewer-branch')

        get api('/merge_requests', user2), params: { scope: 'reviews_for_me' }

        # Should only return the merge request where user2 is a reviewer
        expect_response_contain_exactly(merge_request3.id)
      end

      it 'returns merge requests reacted by the authenticated user by the given emoji' do
        merge_request3 = create(:merge_request, :simple, author: user, assignees: [user], source_project: project2, target_project: project2, source_branch: 'other-branch')
        award_emoji = create(:award_emoji, awardable: merge_request3, user: user2, name: 'star')

        get api('/merge_requests', user2), params: { my_reaction_emoji: award_emoji.name, scope: 'all' }

        expect_response_contain_exactly(merge_request3.id)
      end

      context 'source_branch param' do
        it 'returns merge requests with the given source branch' do
          get api('/merge_requests', user), params: { source_branch: merge_request_closed.source_branch, state: 'all' }

          expect_response_contain_exactly(
            merge_request_merged.id, merge_request_locked.id, merge_request_closed.id
          )
        end
      end

      context 'target_branch param' do
        it 'returns merge requests with the given target branch' do
          get api('/merge_requests', user), params: { target_branch: merge_request_closed.target_branch, state: 'all' }

          expect_response_contain_exactly(
            merge_request_merged.id, merge_request_locked.id, merge_request_closed.id
          )
        end
      end

      context 'with non_archived parameter' do
        let_it_be(:archived_project) { create(:project, :public, :archived, namespace: user.namespace) }
        let_it_be(:archived_merge_request) { create(:merge_request, :simple, author: user, source_project: archived_project) }

        it 'returns merge requests including archived projects by default' do
          get api('/merge_requests', user), params: { scope: 'all' }

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response).to be_an Array
          expect(json_response.map { |mr| mr['id'] }).to include(archived_merge_request.id)
          expect(json_response.map { |mr| mr['id'] }).to include(merge_request.id)
        end

        it 'returns merge requests from non-archived projects only when non_archived is true' do
          get api('/merge_requests', user), params: { non_archived: true, scope: 'all' }

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response).to be_an Array
          expect(json_response.map { |mr| mr['id'] }).not_to include(archived_merge_request.id)
          expect(json_response.map { |mr| mr['id'] }).to include(merge_request.id)
        end

        it 'returns merge requests from archived projects when non_archived is false' do
          get api('/merge_requests', user), params: { non_archived: false, scope: 'all' }

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response).to be_an Array
          expect(json_response.map { |mr| mr['id'] }).to include(archived_merge_request.id)
          expect(json_response.map { |mr| mr['id'] }).to include(merge_request.id)
        end
      end

      it 'returns merge requests created before a specific date' do
        merge_request2 = create(:merge_request, :simple, source_project: project, target_project: project, source_branch: 'feature_1', created_at: Date.new(2000, 1, 1))

        get api('/merge_requests?created_before=2000-01-02T00:00:00.060Z', user)

        expect_response_contain_exactly(merge_request2.id)
      end

      it 'returns merge requests created after a specific date' do
        merge_request2 = create(:merge_request, :simple, source_project: project, target_project: project, source_branch: 'feature_1', created_at: 1.week.from_now)

        get api("/merge_requests?created_after=#{merge_request2.created_at}", user)

        expect_response_contain_exactly(merge_request2.id)
      end

      it 'returns merge requests updated before a specific date' do
        merge_request2 = create(:merge_request, :simple, source_project: project, target_project: project, source_branch: 'feature_1', updated_at: Date.new(2000, 1, 1))

        get api('/merge_requests?updated_before=2000-01-02T00:00:00.060Z', user)

        expect_response_contain_exactly(merge_request2.id)
      end

      it 'returns merge requests updated after a specific date' do
        merge_request2 = create(:merge_request, :simple, source_project: project, target_project: project, source_branch: 'feature_1', updated_at: 1.week.from_now)

        get api("/merge_requests?updated_after=#{merge_request2.updated_at}", user)

        expect_response_contain_exactly(merge_request2.id)
      end

      it 'returns merge requests merged before a specific date' do
        merge_request2 = create(:merge_request, :merged, source_project: project, target_project: project)

        merge_request2.metrics.update!(merged_at: Date.new(2000, 1, 1))

        get api('/merge_requests?merged_before=2000-01-02T00:00:00.060Z', user)

        expect_response_contain_exactly(merge_request2.id)
      end

      it 'returns merge requests merged after a specific date' do
        merge_request2 = create(:merge_request, :merged, source_project: project, target_project: project)

        merge_request2.metrics.update!(merged_at: 1.week.from_now)

        get api("/merge_requests?merged_after=#{merge_request2.metrics.merged_at}", user)

        expect_response_contain_exactly(merge_request2.id)
      end

      context 'search params' do
        let_it_be(:merge_request, freeze: false) do
          create(:merge_request, :simple, author: user, source_project: project, target_project: project, title: 'Search title', description: 'Search description')
        end

        it 'returns merge requests matching given search string for title' do
          get api("/merge_requests", user), params: { search: merge_request.title }

          expect_response_contain_exactly(merge_request.id)
        end

        it 'returns merge requests matching given search string for title and scoped in title' do
          get api("/merge_requests", user), params: { search: merge_request.title, in: 'title' }

          expect_response_contain_exactly(merge_request.id)
        end

        it 'returns an empty array if no merge request matches given search string for description and scoped in title' do
          get api("/merge_requests", user), params: { search: merge_request.description, in: 'title' }

          expect_empty_array_response
        end

        it 'returns merge requests for project matching given search string for description' do
          get api("/merge_requests", user), params: { project_id: project.id, search: merge_request.description }

          expect_response_contain_exactly(merge_request.id)
        end
      end

      context 'state param' do
        it 'returns merge requests with the given state' do
          get api('/merge_requests', user), params: { state: 'locked' }

          expect_response_contain_exactly(merge_request_locked.id)
        end
      end

      it_behaves_like 'authorizing granular token permissions', :read_merge_request do
        let(:boundary_object) { :user }
        let(:request) do
          get api('/merge_requests', personal_access_token: pat), params: { scope: 'all' }
        end
      end
    end

    context 'when merge requests are filtered by authorization' do
      let_it_be(:filter_user) { create(:user) }
      let_it_be(:filter_group) { create(:group) }
      let_it_be(:filter_project) do
        create(:project, :repository, namespace: filter_group, developers: [filter_user])
      end

      let_it_be(:restricted_mr) do
        create(:merge_request, :simple, source_project: filter_project, target_project: filter_project,
          author: filter_user, source_branch: 'restricted-branch')
      end

      let_it_be(:unrestricted_mr) do
        create(:merge_request, :simple, source_project: filter_project, target_project: filter_project,
          author: filter_user, source_branch: 'unrestricted-branch')
      end

      context 'when unauthorized merge requests are not filtered out' do
        it 'includes all merge requests' do
          get api('/merge_requests', filter_user), params: { scope: 'created_by_me' }

          expect_response_contain_exactly(restricted_mr.id, unrestricted_mr.id)
        end
      end

      context 'when Ability filters out unauthorized merge requests' do
        before do
          allow(Ability).to receive(:merge_requests_readable_by_user).and_return([unrestricted_mr])
        end

        it 'includes only authorized merge requests' do
          get api('/merge_requests', filter_user), params: { scope: 'created_by_me' }

          expect_response_contain_exactly(unrestricted_mr.id)
        end
      end
    end
  end

  describe "GET /projects/:id/merge_requests", :use_clean_rails_memory_store_caching do
    include_context 'with merge requests'

    let(:endpoint_path) { "/projects/#{project.id}/merge_requests" }

    it_behaves_like 'enforcing job token policies', :read_merge_requests,
      allow_public_access_for_enabled_project_features: [:repository, :merge_requests] do
      let(:request) do
        get api(endpoint_path), params: { job_token: target_job.token }
      end
    end

    it_behaves_like 'authorizing granular token permissions', :read_merge_request do
      let(:boundary_object) { project }
      let(:request) do
        get api("/projects/#{project.id}/merge_requests", personal_access_token: pat)
      end
    end

    it_behaves_like 'merge requests list'
    it_behaves_like 'merge requests list filters'
    it_behaves_like 'merge requests list reusing ListRefs branch heads'

    context 'caching' do
      it_behaves_like 'merge requests list caching'
    end

    it "returns 404 for non public projects" do
      project = create(:project, :private)

      get api("/projects/#{project.id}/merge_requests")

      expect(response).to have_gitlab_http_status(:not_found)
    end

    it "returns an array of no merge_requests when wip=yes" do
      get api("/projects/#{project.id}/merge_requests", user), params: { wip: 'yes' }

      expect_empty_array_response
    end

    context 'with draft parameter' do
      let_it_be(:draft_mr) { create(:merge_request, :draft_merge_request, author: user, source_project: project, target_project: project) }

      it 'returns only draft merge requests when draft=true' do
        get api("/projects/#{project.id}/merge_requests", user), params: { draft: true }

        expect_response_contain_exactly(draft_mr.id)
      end

      it 'returns only non-draft merge requests when draft=false' do
        get api("/projects/#{project.id}/merge_requests", user), params: { draft: false }

        expect(json_response).not_to include(a_hash_including('id' => draft_mr.id))
        expect(response).to have_gitlab_http_status(:ok)
      end

      it 'returns 400 when both draft and wip are specified' do
        get api("/projects/#{project.id}/merge_requests", user), params: { draft: true, wip: 'yes' }

        expect(response).to have_gitlab_http_status(:bad_request)
      end
    end

    it 'returns merge_request by "iids" array' do
      get api(endpoint_path, user), params: { iids: [merge_request.iid, merge_request_closed.iid] }

      expect_paginated_array_response([merge_request_closed.id, merge_request.id])
      expect(json_response.first['title']).to eq merge_request_closed.title
      expect(json_response.first['id']).to eq merge_request_closed.id
    end

    context 'when filtering by deployments' do
      let_it_be(:mr) do
        create(:merge_request, :merged, source_project: project, target_project: project)
      end

      before do
        env = create(:environment, project: project, name: 'staging')
        deploy = create(:deployment, :success, environment: env, deployable: nil)

        deploy.link_merge_requests(MergeRequest.where(id: mr.id))
      end

      it 'supports getting merge requests deployed to an environment' do
        get api(endpoint_path, user), params: { environment: 'staging' }

        expect(json_response.first['id']).to eq mr.id
      end

      it 'does not return merge requests for an environment without deployments' do
        get api(endpoint_path, user), params: { environment: 'bla' }

        expect_empty_array_response
      end

      it 'supports getting merge requests deployed after a date' do
        get api(endpoint_path, user), params: { deployed_after: '1990-01-01' }

        expect(json_response.first['id']).to eq mr.id
      end

      it 'does not return merge requests not deployed after a given date' do
        get api(endpoint_path, user), params: { deployed_after: '2100-01-01' }

        expect_empty_array_response
      end

      it 'supports getting merge requests deployed before a date' do
        get api(endpoint_path, user), params: { deployed_before: '2100-01-01' }

        expect(json_response.first['id']).to eq mr.id
      end

      it 'does not return merge requests not deployed before a given date' do
        get api(endpoint_path, user), params: { deployed_before: '1990-01-01' }

        expect_empty_array_response
      end

      it 'returns 400 when deployed_before is not a valid date' do
        get api(endpoint_path, user), params: { deployed_before: '2021-99-99' }

        expect(response).to have_gitlab_http_status(:bad_request)
      end

      it 'returns 400 when deployed_after is not a valid date' do
        get api(endpoint_path, user), params: { deployed_after: '2021-99-99' }

        expect(response).to have_gitlab_http_status(:bad_request)
      end
    end

    context 'a project which enforces all discussions to be resolved' do
      let_it_be(:project) do
        create(:project, :repository, only_allow_merge_if_all_discussions_are_resolved: true, reporters: user)
      end

      include_context 'with merge requests'

      it 'avoids N+1 queries', quarantine: 'https://gitlab.com/gitlab-org/quality/test-failure-issues/-/issues/9318' do
        control = ActiveRecord::QueryRecorder.new do
          get api("/projects/#{project.id}/merge_requests", user)
        end

        create(:merge_request, author: user, assignees: [user], source_project: project, target_project: project, created_at: base_time)

        expect do
          get api("/projects/#{project.id}/merge_requests", user)
        end.not_to exceed_query_limit(control)
      end
    end

    context 'when user is an inherited member from the group' do
      let_it_be(:group) { create(:group) }

      shared_examples 'user cannot view merge requests' do
        it 'returns 403 forbidden' do
          get api("/projects/#{group_project.id}/merge_requests", inherited_user)

          expect(response).to have_gitlab_http_status(:forbidden)
        end
      end

      context 'and user is a guest' do
        let_it_be(:inherited_user) { create(:user) }

        before_all do
          group.add_guest(inherited_user)
        end

        context 'when project is public with private merge requests' do
          let_it_be(:group_project) do
            create(
              :project,
              :public,
              group: group,
              merge_requests_access_level: ProjectFeature::DISABLED
            )
          end

          it_behaves_like 'user cannot view merge requests'
        end

        context 'when project is private' do
          let_it_be(:group_project) { create(:project, :private, group: group) }

          it_behaves_like 'user cannot view merge requests'
        end
      end
    end
  end

  describe "GET /groups/:id/merge_requests" do
    let_it_be_with_reload(:group) { create(:group, :public) }
    let_it_be(:project) { create(:project, :public, :repository, creator: user, namespace: group, only_allow_merge_if_pipeline_succeeds: false) }
    let(:endpoint_path) { "/groups/#{group.id}/merge_requests" }

    include_context 'with merge requests'

    before do
      group.add_reporter(user)
    end

    it_behaves_like 'merge requests list'
    it_behaves_like 'merge requests list reusing ListRefs branch heads'

    context 'with filters and sort orders' do
      include_context 'with labels'

      it 'returns the same merge requests in the same order as the project endpoint' do
        [
          { labels: label.title },
          { milestone: milestone1.title, state: 'closed' },
          { not: { labels: label.title } },
          { source_branch: merge_request_closed.source_branch },
          { order_by: 'created_at', sort: 'asc' },
          { order_by: 'updated_at', sort: 'desc' },
          { order_by: 'title', sort: 'asc' },
          { order_by: 'merged_at', sort: 'desc', state: 'merged' },
          { sort: 'desc', per_page: 2, page: 2 }
        ].each do |params|
          get api("/projects/#{project.id}/merge_requests", user), params: params
          project_ids = json_response.pluck('id')

          get api(endpoint_path, user), params: params

          expect(response).to have_gitlab_http_status(:ok)
          expect(project_ids).not_to be_empty
          expect(json_response.pluck('id')).to eq(project_ids), "params: #{params}"
        end
      end
    end

    describe 'total count cache', :use_clean_rails_memory_store_caching do
      let(:count_query) { /SELECT COUNT\(\*\) FROM \(SELECT 1 AS one FROM "merge_requests"/ }

      def list_merge_requests(as: user, **params)
        ActiveRecord::QueryRecorder.new { get api(endpoint_path, as), params: { per_page: 1, **params } }.log
      end

      it 'reuses the count from an earlier request for the same query' do
        list_merge_requests(page: 2)
        total = response.headers['X-Total']

        expect(list_merge_requests(page: 3)).not_to include(a_string_matching(count_query))
        expect(response.headers['X-Total']).to eq(total)
      end

      it 'reuses the count when only serialization params change' do
        list_merge_requests(page: 2)

        expect(list_merge_requests(page: 3, with_labels_details: true)).not_to include(a_string_matching(count_query))
      end

      it 'counts again for another user or other filters' do
        list_merge_requests(page: 2)

        expect(list_merge_requests(as: user2, page: 3)).to include(a_string_matching(count_query))
        expect(list_merge_requests(state: 'opened', page: 3)).to include(a_string_matching(count_query))
      end
    end

    context 'when have subgroups' do
      let_it_be(:subgroup) { create(:group, :public, parent: group) }
      let_it_be(:subgroup_project) { create(:project, :public, namespace: subgroup) }
      let_it_be(:subgroup_label) { create(:label, project: subgroup_project) }
      let_it_be(:subgroup_merge_request) do
        create(:labeled_merge_request, labels: [subgroup_label], author: user, source_project: subgroup_project, target_project: subgroup_project)
      end

      it 'returns merge requests from projects in the group and its subgroups' do
        get api(endpoint_path, user)

        expect_response_contain_exactly(
          merge_request_merged.id, merge_request_locked.id, merge_request_closed.id,
          merge_request.id, subgroup_merge_request.id
        )
      end

      it 'filters by a label of a project in a subgroup' do
        get api(endpoint_path, user), params: { labels: subgroup_label.title }

        expect_response_contain_exactly(subgroup_merge_request.id)
      end
    end

    describe "#to_reference" do
      it 'exposes reference path in context of group' do
        get api("/groups/#{group.id}/merge_requests", user)

        expect(json_response.first['references']['short']).to eq("!#{merge_request_merged.iid}")
        expect(json_response.first['references']['relative']).to eq("#{merge_request_merged.target_project.path}!#{merge_request_merged.iid}")
        expect(json_response.first['references']['full']).to eq("#{merge_request_merged.target_project.full_path}!#{merge_request_merged.iid}")
      end

      context 'referencing from parent group' do
        let(:parent_group) { create(:group) }

        before do
          group.update!(parent_id: parent_group.id)
          merge_request_merged.reload
        end

        it 'exposes reference path in context of parent group' do
          get api("/groups/#{parent_group.id}/merge_requests")

          expect(json_response.first['references']['short']).to eq("!#{merge_request_merged.iid}")
          expect(json_response.first['references']['relative']).to eq("#{merge_request_merged.target_project.full_path}!#{merge_request_merged.iid}")
          expect(json_response.first['references']['full']).to eq("#{merge_request_merged.target_project.full_path}!#{merge_request_merged.iid}")
        end
      end
    end

    context 'with archived projects' do
      let_it_be(:project2) { create(:project, :public, :archived, namespace: group) }
      let_it_be(:merge_request_archived) { create(:merge_request, title: 'archived mr', author: user, source_project: project2, target_project: project2) }

      it 'returns an array excluding merge_requests from archived projects' do
        get api(endpoint_path, user)

        expect_response_contain_exactly(
          merge_request_merged.id, merge_request_locked.id,
          merge_request_closed.id, merge_request.id
        )
      end

      context 'with non_archived param set as false' do
        it 'returns an array including merge_requests from archived projects' do
          path = endpoint_path + '?non_archived=false'

          get api(path, user)

          expect_response_contain_exactly(
            merge_request_merged.id, merge_request_archived.id, merge_request_locked.id,
            merge_request_closed.id, merge_request.id
          )
        end
      end
    end

    it_behaves_like 'authorizing granular token permissions', :read_merge_request do
      let(:boundary_object) { Group.find(group.id) }
      let(:request) do
        get api(endpoint_path, personal_access_token: pat)
      end
    end
  end

  describe 'MCP tool input schemas', feature_category: :mcp_server do
    it 'locks the full input schema of get_merge_request_commits' do
      expect(Mcp::Tools::Manager.new.get_tool(name: 'get_merge_request_commits').input_schema).to eq({
        type: 'object',
        properties: {
          'id' => {
            type: 'string',
            description: 'ID or URL-encoded path of the project.'
          },
          'merge_request_iid' => {
            type: 'integer',
            description: 'Internal ID of the merge request.'
          },
          'per_page' => {
            type: 'integer',
            description: 'Number of items to list per page.'
          },
          'page' => {
            type: 'integer',
            description: 'Page number of results to retrieve.'
          }
        },
        required: %w[id merge_request_iid],
        additionalProperties: false
      })
    end

    it 'locks the full input schema of get_merge_request_diffs' do
      expect(Mcp::Tools::Manager.new.get_tool(name: 'get_merge_request_diffs').input_schema).to eq({
        type: 'object',
        properties: {
          'id' => {
            type: 'string',
            description: 'ID or URL-encoded path of the project.'
          },
          'merge_request_iid' => {
            type: 'integer',
            description: 'Internal ID of the merge request.'
          },
          'per_page' => {
            type: 'integer',
            description: 'Number of items to list per page.'
          },
          'page' => {
            type: 'integer',
            description: 'Page number of results to retrieve.'
          }
        },
        required: %w[id merge_request_iid],
        additionalProperties: false
      })
    end

    it 'locks the full input schema of get_merge_request_pipelines' do
      expect(Mcp::Tools::Manager.new.get_tool(name: 'get_merge_request_pipelines').input_schema).to eq({
        type: 'object',
        properties: {
          'id' => {
            type: 'string',
            description: 'ID or URL-encoded path of the project.'
          },
          'merge_request_iid' => {
            type: 'integer',
            description: 'Internal ID of the merge request.'
          }
        },
        required: %w[id merge_request_iid],
        additionalProperties: false
      })
    end
  end
end
