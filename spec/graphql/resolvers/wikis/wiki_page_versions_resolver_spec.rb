# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Resolvers::Wikis::WikiPageVersionsResolver, :clean_gitlab_redis_repository_cache, feature_category: :wiki do
  include GraphqlHelpers

  let_it_be(:user) { create(:user) }
  let_it_be(:project, freeze: false) { create(:project, :private, :wiki_repo, developers: user) }
  let_it_be(:wiki, freeze: false) { create(:project_wiki, project: project, user: user) }

  let_it_be(:wiki_page_meta, freeze: false) do
    create(:wiki_page, wiki: wiki, title: 'history', content: "v1\n", message: 'create history')
    %w[edit-1 edit-2].each do |message|
      wiki.find_page('history').update(content: "#{message}\n", message: message) # rubocop:disable Rails/SaveBang -- not an ActiveRecord
    end
    create(:wiki_page, wiki: wiki, title: 'unrelated')

    wiki.find_page('history').find_or_create_meta
  end

  let(:history) { Wikis::PageHistory.new(wiki.find_page('history')) }

  describe '#resolve' do
    it 'returns the same versions in the same order as the page history', :aggregate_failures do
      result = resolve_versions

      expect(result.items.map(&:message)).to eq(['edit-2', 'edit-1', 'create history'])
      expect(result.items.map(&:sha)).to eq(history.versions.map(&:sha))
      expect(result.has_next_page).to be(false)
      expect(result.end_cursor).to be_nil
    end

    it 'returns the total count of versions' do
      expect(resolve_versions(args: { first: 1 }).items.precomputed_total_count).to eq(3)
    end

    context 'with pagination' do
      it 'returns the first page with a cursor to the next page', :aggregate_failures do
        result = resolve_versions(args: { first: 2 })

        expect(result.items.map(&:message)).to eq(%w[edit-2 edit-1])
        expect(result.has_next_page).to be(true)
        expect(result.end_cursor).to be_present
      end

      it 'returns the next page without overlap when following the cursor', :aggregate_failures do
        first_page = resolve_versions(args: { first: 2 })
        second_page = resolve_versions(args: { first: 2, after: first_page.end_cursor })

        expect(second_page.items.map(&:message)).to eq(['create history'])
        expect(second_page.has_next_page).to be(false)
        expect(second_page.end_cursor).to be_nil
      end

      it 'reports no next page when first equals the number of versions', :aggregate_failures do
        result = resolve_versions(args: { first: 3 })

        expect(result.items.size).to eq(3)
        expect(result.has_next_page).to be(false)
        expect(result.end_cursor).to be_nil
      end

      it 'returns no versions but the total count when first is 0', :aggregate_failures do
        expect_next_instance_of(Wikis::PageHistory) do |history|
          expect(history).not_to receive(:paginated_versions)
        end

        result = resolve_versions(args: { first: 0 })

        expect(result.items).to be_empty
        expect(result.has_next_page).to be(false)
        expect(result.items.precomputed_total_count).to eq(3)
      end

      it 'floors a negative cursor offset to zero' do
        result = resolve_versions(args: { first: 1, after: Base64.strict_encode64('-5') })

        expect(result.items.map(&:message)).to eq(['edit-2'])
      end

      it 'returns an error for an invalid cursor' do
        expect_graphql_error_to_be_created(Gitlab::Graphql::Errors::ArgumentError, 'Invalid pagination cursor') do
          resolve_versions(args: { first: 1, after: 'not-a-valid-cursor' })
        end
      end
    end

    context 'when the page no longer exists' do
      let_it_be(:missing_page_meta) do
        create(:wiki_page_meta, container: project, title: 'missing').tap do |meta|
          create(:wiki_page_slug, :canonical, wiki_page_meta: meta, slug: 'missing')
        end
      end

      it 'returns an empty result', :aggregate_failures do
        result = resolve_versions(meta: missing_page_meta)

        expect(result.items).to be_empty
        expect(result.items.precomputed_total_count).to eq(0)
      end
    end

    context 'when the user is not authorized to read the wiki' do
      it 'returns nil' do
        expect(resolve_versions(current_user: create(:user))).to be_nil
      end
    end
  end

  private

  def resolve_versions(meta: wiki_page_meta, args: {}, current_user: user)
    resolve(
      described_class,
      obj: meta,
      args: args,
      ctx: { current_user: current_user },
      field_opts: {
        calls_gitaly: true,
        connection_extension: Gitlab::Graphql::Extensions::ForwardOnlyExternallyPaginatedArrayExtension
      }
    )
  end
end
