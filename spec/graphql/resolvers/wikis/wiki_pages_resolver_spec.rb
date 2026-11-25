# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Resolvers::Wikis::WikiPagesResolver, feature_category: :wiki do
  include GraphqlHelpers

  describe '#resolve' do
    let_it_be(:user) { create(:user) }
    let_it_be(:project, freeze: false) { create(:project, :private, developers: user) }

    context 'for project wikis' do
      let_it_be(:wiki_page_meta, freeze: false) { create(:wiki_page_meta, :for_wiki_page, container: project) }

      subject(:resolved_pages) do
        resolve_wiki_pages(project).items
      end

      it 'returns wiki page meta records' do
        expect(resolved_pages).to include(wiki_page_meta)
      end

      context 'when wiki has no pages' do
        let_it_be(:empty_project, freeze: false) { create(:project, :private, developers: user) }

        it 'returns an empty collection' do
          expect(resolve_wiki_pages(empty_project).items).to be_empty
        end
      end

      context 'with pagination' do
        let_it_be(:wiki, freeze: false) { project.wiki }

        # Together with the `wiki_page_meta` page above this gives 3 pages in total, so
        # paginating with `first: 2` yields a full first page and a partial second page.
        let_it_be(:pages, freeze: false) do
          %w[apple banana].map { |title| create(:wiki_page, wiki: wiki, title: title) }
        end

        it 'fetches one extra probe row beyond the requested page size to detect the next page' do
          allow(Wiki).to receive(:for_container).and_return(wiki)
          expect(wiki).to receive(:list_pages).with(limit: 3, offset: 0).and_call_original

          resolve_wiki_pages(project, args: { first: 2 })
        end

        it 'returns the first page with a cursor to the next page' do
          result = resolve_wiki_pages(project, args: { first: 2 })

          expect(result.items.size).to eq(2)
          expect(result.has_next_page).to be(true)
          expect(result.end_cursor).to be_present
        end

        it 'returns the next page without overlap when following the cursor' do
          first_page = resolve_wiki_pages(project, args: { first: 2 })
          second_page = resolve_wiki_pages(project, args: { first: 2, after: first_page.end_cursor })

          expect(second_page.items.size).to eq(1)
          expect(second_page.has_next_page).to be(false)
          expect(second_page.end_cursor).to be_nil

          all_titles = (first_page.items + second_page.items).map(&:title)
          expect(all_titles).to contain_exactly('apple', 'banana', wiki_page_meta.title)
        end

        it 'reports hasNextPage=false when first equals the total page count' do
          result = resolve_wiki_pages(project, args: { first: 3 })

          expect(result.items.size).to eq(3)
          expect(result.has_next_page).to be(false)
          expect(result.end_cursor).to be_nil # no phantom cursor at the boundary
        end

        it 'returns an empty result with no next page, without an unlimited fetch, when first is 0' do
          allow(Wiki).to receive(:for_container).and_return(wiki)
          expect(wiki).not_to receive(:list_pages)

          result = resolve_wiki_pages(project, args: { first: 0 })

          expect(result.items).to be_empty
          expect(result.has_next_page).to be(false)
        end

        it 'floors a negative cursor offset to zero' do
          negative_cursor = Base64.strict_encode64('-5')

          allow(Wiki).to receive(:for_container).and_return(wiki)
          expect(wiki).to receive(:list_pages).with(limit: 3, offset: 0).and_call_original

          resolve_wiki_pages(project, args: { first: 2, after: negative_cursor })
        end

        it 'returns an error for an invalid cursor' do
          expect_graphql_error_to_be_created(
            Gitlab::Graphql::Errors::ArgumentError, 'Invalid pagination cursor'
          ) do
            resolve_wiki_pages(project, args: { first: 2, after: 'not-a-valid-cursor' })
          end
        end
      end

      context 'when the user is not authorized to read the wiki' do
        let_it_be(:unauthorized_user) { create(:user) }

        it 'returns nil without running the resolver' do
          expect(resolve_wiki_pages(project, current_user: unauthorized_user)).to be_nil
        end

        it 'returns nil when sorting and filtering' do
          result = resolve_wiki_pages(
            project, args: { sort: Wiki::DIRECTION_DESC, filter: 'templates' }, current_user: unauthorized_user
          )

          expect(result).to be_nil
        end
      end
    end

    context 'with sort and filter arguments' do
      let_it_be(:sorted_project, freeze: false) { create(:project, :private, developers: user) }
      let_it_be(:wiki, freeze: false) { sorted_project.wiki }

      let_it_be(:pages, freeze: false) do
        %w[cherry templates/report apple uploads/image templates/note banana].map do |title|
          create(:wiki_page, wiki: wiki, title: title)
        end
      end

      let(:all_slugs) { %w[apple banana cherry templates/note templates/report uploads/image] }

      def resolved_slugs(args = {})
        resolve_wiki_pages(sorted_project, args: args).items.map(&:canonical_slug)
      end

      it 'sorts by path in ascending order by default' do
        expect(resolved_slugs).to eq(all_slugs)
      end

      it 'sorts by path in ascending order with PATH_ASC' do
        expect(resolved_slugs(sort: Wiki::DIRECTION_ASC)).to eq(all_slugs)
      end

      it 'sorts by path in descending order with PATH_DESC' do
        expect(resolved_slugs(sort: Wiki::DIRECTION_DESC)).to eq(all_slugs.reverse)
      end

      it 'returns every page with the ALL filter' do
        expect(resolved_slugs(filter: 'all')).to eq(all_slugs)
      end

      it 'excludes templates and uploads with the PAGES filter' do
        expect(resolved_slugs(filter: 'pages')).to eq(%w[apple banana cherry])
      end

      it 'returns only templates with the TEMPLATES filter' do
        expect(resolved_slugs(filter: 'templates')).to eq(%w[templates/note templates/report])
      end

      it 'combines the filter with the sort direction' do
        expect(resolved_slugs(sort: Wiki::DIRECTION_DESC, filter: 'pages')).to eq(%w[cherry banana apple])
      end

      it 'keeps the paginated fetch for PATH_ASC with ALL' do
        allow(Wiki).to receive(:for_container).and_return(wiki)
        expect(wiki).to receive(:list_pages).with(limit: 3, offset: 0).and_call_original

        resolve_wiki_pages(sorted_project, args: { first: 2, sort: Wiki::DIRECTION_ASC, filter: 'all' })
      end

      it 'loads the full list before paginating when sorting or filtering' do
        allow(Wiki).to receive(:for_container).and_return(wiki)
        expect(wiki).to receive(:list_pages).with(direction: Wiki::DIRECTION_DESC).and_call_original

        resolve_wiki_pages(sorted_project, args: { first: 2, sort: Wiki::DIRECTION_DESC })
      end

      it 'sorts in descending order before paginating' do
        first_page = resolve_wiki_pages(sorted_project, args: { first: 2, sort: Wiki::DIRECTION_DESC })
        second_page = resolve_wiki_pages(
          sorted_project, args: { first: 2, sort: Wiki::DIRECTION_DESC, after: first_page.end_cursor }
        )

        expect(first_page.items.map(&:canonical_slug)).to eq(%w[uploads/image templates/report])
        expect(first_page.has_next_page).to be(true)
        expect(second_page.items.map(&:canonical_slug)).to eq(%w[templates/note cherry])
        expect(second_page.has_next_page).to be(true)
      end

      it 'filters before paginating' do
        first_page = resolve_wiki_pages(sorted_project, args: { first: 1, filter: 'templates' })
        second_page = resolve_wiki_pages(
          sorted_project, args: { first: 1, filter: 'templates', after: first_page.end_cursor }
        )

        expect(first_page.items.map(&:canonical_slug)).to eq(%w[templates/note])
        expect(first_page.has_next_page).to be(true)
        expect(second_page.items.map(&:canonical_slug)).to eq(%w[templates/report])
        expect(second_page.has_next_page).to be(false)
        expect(second_page.end_cursor).to be_nil
      end

      it 'returns an empty page when the cursor is past the end of the filtered list' do
        result = resolve_wiki_pages(
          sorted_project, args: { first: 2, filter: 'templates', after: Base64.strict_encode64('10') }
        )

        expect(result.items).to be_empty
        expect(result.has_next_page).to be(false)
        expect(result.end_cursor).to be_nil
      end
    end
  end

  describe '.resolver_complexity' do
    let(:default_complexity) do
      described_class.resolver_complexity({ sort: Wiki::DIRECTION_ASC, filter: 'all' }, child_complexity: 1)
    end

    where(:args) do
      [
        [{ sort: Wiki::DIRECTION_DESC, filter: 'all' }],
        [{ sort: Wiki::DIRECTION_ASC, filter: 'pages' }],
        [{ sort: Wiki::DIRECTION_ASC, filter: 'templates' }],
        [{ sort: Wiki::DIRECTION_DESC, filter: 'templates' }]
      ]
    end

    with_them do
      it 'charges extra when the full list is loaded' do
        expect(described_class.resolver_complexity(args, child_complexity: 1))
          .to eq(default_complexity + described_class::FULL_LIST_COMPLEXITY)
      end
    end
  end

  private

  def resolve_wiki_pages(container, args: {}, current_user: user)
    resolve(
      described_class,
      obj: container,
      args: args,
      ctx: { current_user: current_user },
      field_opts: {
        calls_gitaly: true,
        connection_extension: Gitlab::Graphql::Extensions::ForwardOnlyExternallyPaginatedArrayExtension
      }
    )
  end
end
