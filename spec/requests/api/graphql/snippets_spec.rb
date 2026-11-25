# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'snippets', :with_current_organization, feature_category: :source_code_management do
  include GraphqlHelpers

  let_it_be(:current_user) { create(:user) }
  let_it_be(:snippets) { create_list(:personal_snippet, 3, :repository, author: current_user) }

  describe 'querying for all fields' do
    before do
      # Mock the expensive blob highlighting operations
      allow(Gitlab::Highlight).to receive(:highlight).and_return('mocked highlighted content')
    end

    let(:query) do
      graphql_query_for(:snippets, { ids: [global_id_of(snippets.first)] }, <<~SELECT)
        nodes { #{all_graphql_fields_for('Snippet')} }
      SELECT
    end

    it 'can successfully query for snippets and their blobs' do
      post_graphql(query, current_user: current_user)

      expect(graphql_data_at(:snippets, :nodes)).to be_one
      expect(graphql_data_at(:snippets, :nodes, :blobs, :nodes)).to be_present
    end
  end

  describe 'granular PAT authorization' do
    let(:user) { current_user }
    let(:request) { post_graphql(query, token: { personal_access_token: pat }) }

    context 'with a personal snippet' do
      let(:boundary_object) { :user }
      let(:query) do
        graphql_query_for(:snippets, { ids: [global_id_of(snippets.first)] }, 'nodes { title }')
      end

      it_behaves_like 'authorizing granular token permissions for GraphQL', :read_snippet

      it 'returns the snippet to a token that can read the snippets of its user' do
        assignable = ::Authz::PermissionGroups::Assignable.for_permission(:read_snippet).min_by(&:name).name
        token = create(:granular_pat, user: user, boundary: ::Authz::Boundary.for(:user), permissions: [assignable])

        post_graphql(query, token: { personal_access_token: token })

        expect(graphql_data_at(:snippets, :nodes, :title)).to contain_exactly(snippets.first.title)
      end
    end

    context 'with a project snippet' do
      let_it_be(:project) { create(:project, :private, developers: current_user) }
      let_it_be(:project_snippet) do
        create(:project_snippet, :private, :repository, project: project, author: current_user)
      end

      let(:boundary_object) { project }
      let(:snippet_fields) { 'title' }
      let(:query) do
        graphql_query_for(:project, { full_path: project.full_path }, "snippets { nodes { #{snippet_fields} } }")
      end

      it_behaves_like 'authorizing granular token permissions for GraphQL', [:read_project, :read_snippet]

      it_behaves_like 'denying a granular token that only authorizes the parent of a field', :read_project do
        let(:parent_data_path) { %i[project] }
        let(:field_data_path) { %i[project snippets] }
      end

      it_behaves_like 'authorizing granular token permissions for GraphQL with a skipped child type',
        [:read_project, :read_snippet] do
        let(:snippet_fields) { 'blobs { nodes { path } }' }
        let(:skipped_data_path) { %i[project snippets nodes blobs nodes path] }
      end

      it_behaves_like 'authorizing granular token permissions for GraphQL with a skipped child type',
        [:read_project, :read_snippet] do
        let(:snippet_fields) { 'blobs { nodes { simpleViewer { type } } }' }
        let(:skipped_data_path) { %i[project snippets nodes blobs nodes simple_viewer type] }
      end

      it_behaves_like 'authorizing granular token permissions for GraphQL with a skipped child type',
        [:read_project, :read_snippet] do
        let(:snippet_fields) { 'blobs { nodes { richViewer { type } } }' }
        let(:skipped_data_path) { %i[project snippets nodes blobs nodes rich_viewer type] }
      end

      it_behaves_like 'authorizing granular token permissions for GraphQL with a skipped child type',
        [:read_project, :read_snippet] do
        let(:snippet_fields) { 'userPermissions { readSnippet }' }
        let(:skipped_data_path) { %i[project snippets nodes user_permissions read_snippet] }
      end
    end
  end

  describe 'snippet blob complexity' do
    it 'applies higher complexity to blob content fields' do
      blob_type = Types::Snippets::BlobType

      expect(blob_type.fields['rawPlainData'].complexity).to eq(10)
      expect(blob_type.fields['richData'].complexity).to eq(10)
      expect(blob_type.fields['plainData'].complexity).to eq(10)
    end

    it 'limits more than 8 aliased blob data requests' do
      # create query with 9 aliased rawPlainData fields
      query_string = build_blob_query(%w[a b c d e f g h i].to_h { |key| [key.to_sym, 'rawPlainData'] })
      complexity_score = calculate_query_complexity(query_string)

      expect(complexity_score).to be > GitlabSchema::DEFAULT_MAX_COMPLEXITY
    end

    it 'allows queries within complexity limits' do
      query_string = build_blob_query({ field1: 'rawPlainData', field2: 'name' })
      complexity_score = calculate_query_complexity(query_string)

      expect(complexity_score).to be < GitlabSchema::DEFAULT_MAX_COMPLEXITY
    end
  end

  describe 'project snippets complexity' do
    let_it_be(:project) { create(:project, :public) }

    it 'blocks high complexity queries with multiple project aliases' do
      # Build query with multiple project aliases requesting blob data
      query_string = <<~GRAPHQL
        query {
          p1: project(fullPath: "#{project.full_path}") {
            snippets(first: 100) {
              nodes {
                blobs {
                  nodes {
                    rawPlainData
                  }
                }
              }
            }
          }
          p2: project(fullPath: "#{project.full_path}") {
            snippets(first: 100) {
              nodes {
                blobs {
                  nodes {
                    rawPlainData
                  }
                }
              }
            }
          }
        }
      GRAPHQL

      complexity_score = calculate_query_complexity(query_string)
      expect(complexity_score).to be > GitlabSchema::DEFAULT_MAX_COMPLEXITY
    end

    it 'allows single-project snippet queries' do
      query_string = <<~GRAPHQL
        query {
          project(fullPath: "#{project.full_path}") {
            snippets(first: 100) {
              nodes {
                title
                blobs {
                  nodes {
                    rawPlainData
                  }
                }
              }
            }
          }
        }
      GRAPHQL

      complexity_score = calculate_query_complexity(query_string)
      expect(complexity_score).to be < GitlabSchema::DEFAULT_MAX_COMPLEXITY
    end
  end

  private

  def build_blob_query(field_map)
    field_requests = field_map.map { |alias_name, field| "#{alias_name}: #{field}" }

    <<~GRAPHQL
    query {
      project(fullPath: "test") {
        snippets {
          nodes {
            blobs {
              nodes {
                #{field_requests.join("\n")}
              }
            }
          }
        }
      }
    }
    GRAPHQL
  end
end
