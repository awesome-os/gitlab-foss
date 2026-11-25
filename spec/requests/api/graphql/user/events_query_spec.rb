# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Getting events of a user', feature_category: :user_profile do
  include GraphqlHelpers

  let_it_be_with_reload(:target_user) { create(:user) }
  let_it_be(:project) { create(:project, :public) }

  let_it_be(:push_event) { create(:push_event, project: project, author: target_user) }
  let_it_be(:merge_event) do
    create(:event, :merged,
      project: project,
      author: target_user,
      target: create(:merge_request, source_project: project))
  end

  let_it_be(:issue_event) do
    create(:event, :created,
      project: project,
      author: target_user,
      target: create(:issue, project: project))
  end

  let_it_be(:comment_event) do
    create(:event, :commented,
      project: project,
      author: target_user,
      target: create(:note, project: project))
  end

  let_it_be(:path) { %i[user events nodes] }

  let(:user_params) { { username: target_user.username } }
  let(:query) { graphql_query_for(:user, user_params, query_nodes(:events, :id)) }

  let(:events) do
    post_graphql(query, current_user: current_user)

    graphql_data_at(*path)
  end

  context 'when the target user profile is readable' do
    let(:current_user) { target_user }

    it_behaves_like 'a working graphql query' do
      before do
        post_graphql(query, current_user: current_user)
      end
    end

    it 'returns the events authored by the target user' do
      expect(events).to contain_exactly(
        a_graphql_entity_for(push_event),
        a_graphql_entity_for(merge_event),
        a_graphql_entity_for(issue_event),
        a_graphql_entity_for(comment_event)
      )
    end

    it 'returns the events with the most recent first' do
      expect(events.pluck('id')).to eq(
        [comment_event, issue_event, merge_event, push_event].map { |event| event.to_global_id.to_s }
      )
    end

    context 'when filtering by event type' do
      using RSpec::Parameterized::TableSyntax

      where(:filter, :expected_event) do
        :PUSH     | ref(:push_event)
        :MERGED   | ref(:merge_event)
        :ISSUE    | ref(:issue_event)
        :COMMENTS | ref(:comment_event)
      end

      with_them do
        it 'returns only the events matching the filter' do
          filtered_query = graphql_query_for(:user, user_params, query_nodes(:events, :id, args: { filter: filter }))

          post_graphql(filtered_query, current_user: current_user)

          expect(graphql_data_at(*path)).to contain_exactly(a_graphql_entity_for(expected_event))
        end
      end
    end

    it 'avoids N+1 queries', :use_sql_query_cache do
      fields = 'id action author { id } project { id }'
      events_query = graphql_query_for(:user, user_params, query_nodes(:events, fields))

      post_graphql(events_query, current_user: current_user)

      control = ActiveRecord::QueryRecorder.new(skip_cached: false) do
        post_graphql(events_query, current_user: current_user)
      end

      create(:event, :closed,
        project: project,
        author: target_user,
        target: create(:issue, project: project))

      expect do
        post_graphql(events_query, current_user: current_user)
      end.not_to exceed_all_query_limit(control)
    end
  end

  context 'when the target user profile is private' do
    let(:current_user) { create(:user) }

    before do
      target_user.update!(private_profile: true)
    end

    it 'returns no events' do
      expect(events).to be_empty
    end
  end

  context 'with a granular personal access token' do
    let_it_be(:author) { create(:user, :with_namespace) }
    let_it_be(:group) { create(:group, :private, developers: author) }
    let_it_be(:private_project) { create(:project, :private, developers: author) }
    let_it_be(:other_project) { create(:project, :private, developers: author) }

    let_it_be(:project_event) do
      create(:event, :created,
        project: private_project,
        author: author,
        target: create(:issue, project: private_project))
    end

    let_it_be(:other_project_event) do
      create(:event, :created,
        project: other_project,
        author: author,
        target: create(:issue, project: other_project))
    end

    let_it_be(:group_event) do
      create(:event, :transferred, project: nil, group: group, author: author, target: group, target_type: 'Group')
    end

    let_it_be(:personal_event) do
      create(:event, :commented,
        project: nil,
        author: author,
        target: create(:note_on_personal_snippet, author: author, noteable: create(:personal_snippet, author: author)))
    end

    let_it_be(:private_push_event) { create(:push_event, project: private_project, author: author) }
    let_it_be(:private_push_event_payload) { create(:push_event_payload, event: private_push_event) }

    let(:user) { author }
    let(:user_params) { { username: author.username } }
    let(:request) { post_graphql(query, token: { personal_access_token: pat }) }
    let(:event_ids) { graphql_data_at(*path).pluck('id') }

    def assignable_for(permission)
      ::Authz::PermissionGroups::Assignable.preferred_for_permission(permission).name
    end

    def granular_pat_for(event_boundaries)
      create(:granular_pat,
        user: author,
        boundary: ::Authz::Boundary.for(:user),
        permissions: [assignable_for(:read_user)],
        additional_scopes: event_boundaries.map do |event_boundary|
          { boundary: ::Authz::Boundary.for(event_boundary), permissions: [assignable_for(:read_event)] }
        end)
    end

    it_behaves_like 'authorizing granular token permissions for GraphQL', :read_user,
      additional_boundaries: { private_project: :read_event } do
      let(:boundary_object) { :user }
    end

    it_behaves_like 'denying a granular token that only authorizes the parent of a field', :read_user do
      let(:boundary_object) { :user }
      let(:parent_data_path) { %i[user] }
      let(:field_data_path) { %i[user events] }
    end

    context 'when the token authorizes one boundary of the events' do
      using RSpec::Parameterized::TableSyntax

      where(:event_boundary, :expected_event) do
        ref(:private_project) | ref(:project_event)
        ref(:group)           | ref(:group_event)
      end

      with_them do
        let(:pat) { granular_pat_for([event_boundary]) }

        it 'returns only the events of that boundary', :aggregate_failures do
          request

          expect_graphql_errors_to_be_empty
          expect(event_ids).to include(expected_event.to_global_id.to_s)
          expect(event_ids).not_to include(other_project_event.to_global_id.to_s)
        end
      end
    end

    context 'when the token authorizes read_event on the user' do
      let(:pat) do
        create(:granular_pat, user: author, boundary: ::Authz::Boundary.for(:user),
          permissions: [assignable_for(:read_user), assignable_for(:read_event)])
      end

      it 'returns the events outside any project or group only', :aggregate_failures do
        request

        expect_graphql_errors_to_be_empty
        expect(event_ids).to contain_exactly(personal_event.to_global_id.to_s)
      end
    end

    context 'when the token authorizes both projects' do
      let(:pat) { granular_pat_for([private_project, other_project]) }

      it 'returns the events of both projects', :aggregate_failures do
        request

        expect_graphql_errors_to_be_empty
        expect(event_ids).to include(project_event.to_global_id.to_s, other_project_event.to_global_id.to_s)
      end
    end

    context 'when the token holds no scope for the public project or group of an event' do
      let_it_be(:public_events) do
        public_group = create(:group, :public, developers: author)
        public_project = create(:project, :public, developers: author)

        {
          project: create(:event, :created,
            project: public_project, author: author, target: create(:issue, project: public_project)),
          confidential_issue: create(:event, :created,
            project: public_project, author: author, target: create(:issue, :confidential, project: public_project)),
          group: create(:event, :transferred,
            project: nil, group: public_group, author: author, target: public_group, target_type: 'Group')
        }
      end

      let(:pat) { granular_pat_for([]) }

      it 'returns the events every visitor of the project or group can read', :aggregate_failures do
        request

        expect_graphql_errors_to_be_empty
        expect(event_ids).to include(*public_events.values_at(:project, :group).map { |event| event.to_global_id.to_s })
        expect(event_ids).not_to include(
          public_events[:confidential_issue].to_global_id.to_s, project_event.to_global_id.to_s
        )
      end
    end

    context 'when requesting the payload of a push event' do
      let(:query) do
        graphql_query_for(:user, user_params,
          query_nodes(:events, 'id pushEventPayload { action ref { name } commit { count } }'))
      end

      let(:push_event_node) do
        graphql_data_at(*path).find { |node| node['id'] == private_push_event.to_global_id.to_s }
      end

      context 'when the token authorizes read_event on the project' do
        let(:pat) { granular_pat_for([private_project]) }

        it 'returns the payload', :aggregate_failures do
          request

          expect_graphql_errors_to_be_empty
          expect(push_event_node.dig('pushEventPayload', 'ref', 'name')).to eq('master')
          expect(push_event_node.dig('pushEventPayload', 'commit', 'count')).to eq(1)
        end
      end

      context 'when the token only authorizes read_event on another project' do
        let(:pat) { granular_pat_for([other_project]) }

        it 'returns neither the event nor its payload', :aggregate_failures do
          request

          expect_graphql_errors_to_be_empty
          expect(push_event_node).to be_nil
        end
      end
    end
  end
end
