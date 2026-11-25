# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['WikiPage'], feature_category: :wiki do
  include GraphqlHelpers

  let_it_be(:developer) { create(:user) }
  let_it_be_with_reload(:project) { create(:project, :private, developers: developer) }
  let_it_be_with_reload(:wiki_page_meta) { create(:wiki_page_meta, :for_wiki_page, container: project) }

  it 'has the correct fields' do
    expected_fields = [
      :id, :title, :notes, :discussions, :commenters,
      :user_permissions, :web_url, :name, :subscribed, :award_emoji, :slug, :content, :versions
    ]

    expect(described_class).to have_graphql_fields(*expected_fields)
  end

  it 'marks content as calling Gitaly' do
    expect(described_class.fields['content']).to be_calls_gitaly
  end

  describe 'permissions' do
    let(:query) do
      %(
        {
          wikiPage(slug: "#{wiki_page_meta.slugs.first.slug}", projectId: "#{global_id_of(project)}") {
            id
            title
            webUrl
            name
            content
          }
        }
      )
    end

    subject(:response) do
      GitlabSchema.execute(query, context: { current_user: current_user }).as_json['data']['wikiPage']
    end

    context 'when user is a member of the project' do
      let(:current_user) { developer }

      it 'has wiki page title' do
        expect(response['title']).to eq(wiki_page_meta.title)
      end

      it 'has wiki page content' do
        expect(response['content']).to eq(wiki_page_meta.wiki_page.content)
      end
    end

    context 'when user is not logged in' do
      let(:current_user) { nil }

      it 'returns wiki page as nil' do
        expect(response).to be_nil
      end
    end

    context 'when user is not a member of the project' do
      let(:current_user) { build(:user) }

      it 'returns wiki page as nil' do
        expect(response).to be_nil
      end
    end
  end

  describe 'versions' do
    let_it_be(:versions_project, freeze: false) { create(:project, :private, developers: developer) }
    let_it_be(:page_meta, freeze: false) do
      create(:wiki_page_meta, :for_wiki_page, container: versions_project).tap do |meta|
        meta.wiki_page.update(content: 'edited', message: 'edit page') # rubocop:disable Rails/SaveBang -- not an ActiveRecord
      end
    end

    let(:current_user) { developer }
    let(:query) do
      %(
        {
          wikiPage(slug: "#{page_meta.slugs.first.slug}", projectId: "#{global_id_of(versions_project)}") {
            versions(first: 1) {
              count
              nodes { sha authorName message authoredDate }
            }
          }
        }
      )
    end

    subject(:versions) do
      GitlabSchema.execute(query, context: { current_user: current_user }).as_json.dig('data', 'wikiPage', 'versions')
    end

    it 'returns the latest version and the total count', :aggregate_failures do
      commit = page_meta.wiki_page.version

      expect(versions['count']).to eq(2)
      expect(versions['nodes']).to contain_exactly(
        'sha' => commit.sha,
        'authorName' => commit.author_name,
        'message' => 'edit page',
        'authoredDate' => commit.authored_date.iso8601
      )
    end

    context 'when user is not a member of the project' do
      let(:current_user) { build(:user) }

      it { is_expected.to be_nil }
    end
  end

  describe 'authorizations' do
    specify { expect(described_class).to require_graphql_authorizations(:read_wiki) }
  end
end
