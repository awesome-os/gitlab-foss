# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Namespace.savedViews', feature_category: :planning_views do
  include GraphqlHelpers

  let_it_be(:group) { create(:group, :private) }
  let_it_be(:project) { create(:project, :private, group: group) }
  let_it_be(:user) { create(:user, developer_of: group) }
  let_it_be(:group_saved_view) { create(:saved_view, namespace: group, author: user) }
  let_it_be(:project_saved_view) { create(:saved_view, namespace: project.project_namespace, author: user) }

  let(:saved_views_field) { query_graphql_field(:saved_views, {}, 'nodes { id name }') }
  let(:request) { post_graphql(query, token: { personal_access_token: pat }) }

  describe 'CRM contact filters' do
    context 'when the contact has no remaining work item associations' do
      let_it_be(:contact) { create(:contact, group: group) }
      let_it_be(:issue) { create(:issue, project: project) }
      let_it_be_with_reload(:issue_contact) do
        create(:issue_customer_relations_contact, issue: issue, contact: contact)
      end

      let_it_be_with_reload(:saved_view_with_contact) do
        create(:saved_view, namespace: group, author: user, filter_data: { crm_contact_id: contact.id.to_s })
      end

      let(:saved_views_field) do
        query_graphql_field(:saved_views, { id: saved_view_with_contact.to_global_id.to_s },
          'nodes { filters filterWarnings { field message } }')
      end

      let(:query) { graphql_query_for(:namespace, { full_path: group.full_path }, saved_views_field) }

      before do
        issue_contact.destroy!
      end

      it 'retains the contact filter without a warning', :aggregate_failures do
        post_graphql(query, current_user: user)

        expect(graphql_errors).to be_nil
        expect(graphql_data_at(:namespace, :saved_views, :nodes)).to contain_exactly(
          'filters' => { 'crmContactId' => contact.id.to_s },
          'filterWarnings' => []
        )
        expect(saved_view_with_contact.reload.filter_data).to eq('crm_contact_id' => contact.id.to_s)
      end
    end
  end

  describe 'granular PAT authorization' do
    context 'when querying a group through the namespace field' do
      let(:boundary_object) { group }
      let(:query) { graphql_query_for(:namespace, { full_path: group.full_path }, saved_views_field) }

      it_behaves_like 'authorizing granular token permissions for GraphQL',
        [:read_namespace, :read_work_item_saved_view]

      it_behaves_like 'denying a granular token that only authorizes the parent of a field', :read_namespace do
        let(:parent_data_path) { %i[namespace] }
        let(:field_data_path) { %i[namespace saved_views] }
      end
    end

    context 'when querying a project namespace through the namespace field' do
      let(:boundary_object) { project }
      let(:query) { graphql_query_for(:namespace, { full_path: project.full_path }, saved_views_field) }

      it_behaves_like 'authorizing granular token permissions for GraphQL',
        [:read_namespace, :read_work_item_saved_view]

      it_behaves_like 'denying a granular token that only authorizes the parent of a field', :read_namespace do
        let(:parent_data_path) { %i[namespace] }
        let(:field_data_path) { %i[namespace saved_views] }
      end
    end

    context 'when querying through the group field' do
      let(:boundary_object) { group }
      let(:query) { graphql_query_for(:group, { full_path: group.full_path }, saved_views_field) }

      it_behaves_like 'authorizing granular token permissions for GraphQL', [:read_group, :read_work_item_saved_view]

      it_behaves_like 'denying a granular token that only authorizes the parent of a field', :read_group do
        let(:parent_data_path) { %i[group] }
        let(:field_data_path) { %i[group saved_views] }
      end
    end
  end

  describe 'filterWarnings' do
    let(:saved_views_field) do
      query_graphql_field(:saved_views, { id: stale_saved_view.to_global_id.to_s },
        'nodes { filterWarnings { field message } }')
    end

    let(:query) { graphql_query_for(:namespace, { full_path: boundary_object.full_path }, saved_views_field) }

    shared_examples 'checking read_work_item for filter warnings' do
      it_behaves_like 'authorizing granular token permissions for GraphQL with a skipped child type',
        [:read_namespace, :read_work_item_saved_view, :read_work_item] do
        let(:skipped_data_path) { [:namespace, :saved_views, :nodes, 0, :filter_warnings] }
      end

      it_behaves_like 'denying a granular token that only authorizes the parent of a field',
        [:read_namespace, :read_work_item_saved_view] do
        let(:parent_data_path) { %i[namespace saved_views nodes] }
        let(:field_data_path) { [:namespace, :saved_views, :nodes, 0, :filter_warnings] }
      end
    end

    context 'when the saved view belongs to a group' do
      let_it_be(:stale_saved_view) do
        create(:saved_view, namespace: group, author: user, filter_data: { author_ids: [non_existing_record_id] })
      end

      let(:boundary_object) { group }

      it_behaves_like 'checking read_work_item for filter warnings'
    end

    context 'when the saved view belongs to a project' do
      let_it_be(:stale_saved_view) do
        create(:saved_view, namespace: project.project_namespace, author: user,
          filter_data: { author_ids: [non_existing_record_id] })
      end

      let(:boundary_object) { project }

      it_behaves_like 'checking read_work_item for filter warnings'
    end
  end
end

# Browse views loads the next page with `after`. That path applies the cursor in the
# GraphQL connection, which is separate from `keyset_paginate`.
RSpec.describe 'Namespace.savedViews NAME_ASC pagination', feature_category: :planning_views do
  include GraphqlHelpers

  let_it_be(:sort_group) { create(:group, :private) }
  let_it_be(:sort_user) { create(:user, developer_of: sort_group) }

  # Created out of natural order so an id sort cannot pass as NAME_ASC.
  before_all do
    %w[10 20 1 2].each do |name|
      create(:saved_view, namespace: sort_group, name: name, author: sort_user)
    end
  end

  def saved_views_page_query(after: nil)
    args = { sort: :NAME_ASC, first: 2 }
    args[:after] = after if after

    graphql_query_for(
      :namespace,
      { full_path: sort_group.full_path },
      query_graphql_field(:saved_views, args, 'nodes { name } pageInfo { endCursor hasNextPage }')
    )
  end

  it 'returns the second page in natural order' do
    post_graphql(saved_views_page_query, current_user: sort_user)

    first_page = graphql_data_at(:namespace, :saved_views)

    expect(graphql_errors).to be_nil
    expect(first_page['nodes'].pluck('name')).to eq(%w[1 2])
    expect(first_page.dig('pageInfo', 'hasNextPage')).to be(true)

    post_graphql(
      saved_views_page_query(after: first_page.dig('pageInfo', 'endCursor')),
      current_user: sort_user
    )

    second_page = graphql_data_at(:namespace, :saved_views)

    expect(graphql_errors).to be_nil
    expect(second_page['nodes'].pluck('name')).to eq(%w[10 20])
    expect(second_page.dig('pageInfo', 'hasNextPage')).to be(false)
  end
end
