# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'getting a project wiki pages list', feature_category: :wiki do
  include GraphqlHelpers

  let_it_be(:current_user) { create(:user) }
  let_it_be(:project, freeze: false) { create(:project, :private, developers: current_user) }
  let_it_be(:wiki, freeze: false) { project.wiki }

  let_it_be(:wiki_pages, freeze: false) do
    %w[apple banana].map { |title| create(:wiki_page, wiki: wiki, title: title) }
  end

  let(:query) do
    graphql_query_for(
      :project,
      { full_path: project.full_path },
      query_nodes(:wiki_pages, 'title', args: { first: 1 }, include_pagination_info: true)
    )
  end

  # Guards that the `wiki_pages` field on ProjectType is wired with the forward-only
  # externally-paginated connection extension. Without it, `first` never reaches the resolver,
  # so it fetches all pages and reports `hasNextPage: false`, failing this example.
  it 'paginates through the connection extension' do
    post_graphql(query, current_user: current_user)

    expect(graphql_errors).to be_nil
    expect(graphql_data_at(:project, :wiki_pages, :nodes).size).to eq(1)
    expect(graphql_data_at(:project, :wiki_pages, :page_info, :has_next_page)).to be(true)
  end

  it 'resolves versions for only one wiki page per request' do
    versions_query = graphql_query_for(
      :project,
      { full_path: project.full_path },
      query_nodes(:wiki_pages, query_nodes(:versions, 'sha'))
    )

    post_graphql(versions_query, current_user: current_user)

    expect_graphql_errors_to_include('"versions" field can be requested only for 1 WikiPage(s) at a time.')
  end

  it 'returns nil for a user who cannot read the wiki' do
    post_graphql(query, current_user: create(:user))

    expect(graphql_data_at(:project, :wiki_pages)).to be_nil
  end

  context 'with sort and filter arguments' do
    let_it_be(:sorted_project, freeze: false) { create(:project, :private, developers: current_user) }

    let_it_be(:pages, freeze: false) do
      %w[apple banana templates/note].map { |title| create(:wiki_page, wiki: sorted_project.wiki, title: title) }
    end

    let(:args) { { first: 2, sort: :PATH_DESC, filter: :PAGES } }

    let(:query) do
      graphql_query_for(
        :project,
        { full_path: sorted_project.full_path },
        query_nodes(:wiki_pages, 'slug', args: args)
      )
    end

    it 'returns the filtered pages in the requested order' do
      post_graphql(query, current_user: current_user)

      expect(graphql_errors).to be_nil
      expect(graphql_data_at(:project, :wiki_pages, :nodes, :slug)).to eq(%w[banana apple])
    end

    context 'when sort is null' do
      let(:args) { { sort: nil } }

      it 'returns an error' do
        post_graphql(query, current_user: current_user)

        expect_graphql_errors_to_include('sort can\'t be null')
      end
    end

    it 'returns nil for a user who cannot read the wiki' do
      post_graphql(query, current_user: create(:user))

      expect(graphql_data_at(:project, :wiki_pages)).to be_nil
    end

    context 'when aliasing the field many times' do
      let(:aliased_query) do
        fields = Array.new(10) do |i|
          "pages#{i}: #{query_graphql_field(:wiki_pages, wiki_args, 'nodes { slug }')}"
        end

        graphql_query_for(:project, { full_path: sorted_project.full_path }, fields.join("\n"))
      end

      context 'with the default sort and filter' do
        let(:wiki_args) { { first: 1 } }

        it 'runs the query' do
          post_graphql(aliased_query, current_user: current_user)

          expect(graphql_errors).to be_nil
        end
      end

      context 'with a non-default sort or filter' do
        let(:wiki_args) { { first: 1, filter: :PAGES } }

        it 'rejects the query as too complex' do
          post_graphql(aliased_query, current_user: current_user)

          expect_graphql_errors_to_include(/which exceeds max complexity/)
        end
      end
    end
  end
end
