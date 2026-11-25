# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'getting a WorkItem description template and content', feature_category: :groups_and_projects do
  include GraphqlHelpers

  let_it_be(:current_user) { create(:user) }
  let_it_be(:group) do
    create(:group).tap do |g|
      g.add_owner(current_user)
    end
  end

  let_it_be(:template_files) do
    {
      ".gitlab/issue_templates/project_issues_template_a.md" => "project_issues_template_a content",
      ".gitlab/issue_templates/project_issues_template_b.md" => "project_issues_template_b content"
    }
  end

  let_it_be(:project) { create(:project, :custom_repo, files: template_files, group: group) }

  let(:expected_graphql_data) { graphql_data['workItemDescriptionTemplateContent'] }

  context 'with expected arguments' do
    let(:query) do
      graphql_query_for(:workItemDescriptionTemplateContent,
        { templateContentInput: { projectId: project.id, name: "project_issues_template_a" } })
    end

    it 'returns the expected values for the template being queried' do
      post_graphql(query, current_user: current_user)

      expect(expected_graphql_data["projectId"]).to eq(project.id.to_s)
      expect(expected_graphql_data["name"]).to eq("project_issues_template_a")
      expect(expected_graphql_data["category"]).to be_nil
      expect(expected_graphql_data["content"]).to eq("project_issues_template_a content")

      expect(response).to have_gitlab_http_status(:ok)
      expect(graphql_errors).to be_nil
    end
  end

  context 'with a project ID that does not fit in a 32-bit integer' do
    let_it_be(:large_id_project) do
      create(:project, :custom_repo, id: 9_000_000_004_833, files: template_files, group: group)
    end

    let(:query) do
      graphql_query_for(:workItemDescriptionTemplateContent,
        { templateContentInput: { projectId: large_id_project.id, name: "project_issues_template_a" } })
    end

    # The fixed ID means a fixed repository path that outlives the database
    # rollback, so remove it or later runs fail the repository absence check.
    after(:context) do
      large_id_project.repository.raw.remove
    end

    it 'returns the template' do
      post_graphql(query, current_user: current_user)

      expect(graphql_errors).to be_nil
      expect(expected_graphql_data["projectId"]).to eq('9000000004833')
      expect(expected_graphql_data["content"]).to eq("project_issues_template_a content")
    end

    it 'accepts the project ID as a string variable, as the frontend sends it' do
      query = <<~GQL
        query($projectId: BigInt!) {
          workItemDescriptionTemplateContent(
            templateContentInput: { projectId: $projectId, name: "project_issues_template_a" }
          ) {
            projectId
            content
          }
        }
      GQL

      post_graphql(query, current_user: current_user, variables: { projectId: large_id_project.id.to_s })

      expect(graphql_errors).to be_nil
      expect(expected_graphql_data["projectId"]).to eq('9000000004833')
      expect(expected_graphql_data["content"]).to eq("project_issues_template_a content")
    end
  end

  context 'when user does not have access to the project' do
    let_it_be(:unauthorized_user) { create(:user) }
    let(:query) do
      graphql_query_for(:workItemDescriptionTemplateContent,
        { templateContentInput: { projectId: project.id, name: "project_issues_template_a" } })
    end

    it 'does not retrieve the template' do
      post_graphql(query, current_user: unauthorized_user)

      expect(expected_graphql_data).to be_nil
    end
  end

  context 'with a group_id that does not exist' do
    let(:query) do
      graphql_query_for(:workItemDescriptionTemplateContent,
        { templateContentInput: { projectId: -1, name: "project_issues_template_a" } })
    end

    it 'does not retrieve the template' do
      post_graphql(query, current_user: current_user)

      expect(expected_graphql_data).to be_nil
    end
  end

  context 'with a template name that does not exist' do
    let(:query) do
      graphql_query_for(:workItemDescriptionTemplateContent,
        { templateContentInput: { projectId: project.id, name: "missing template" } })
    end

    it 'does not retrieve the template' do
      post_graphql(query, current_user: current_user)

      expect(expected_graphql_data).to be_nil
    end
  end

  context 'when two templates from different projects have identical names' do
    let(:query) do
      graphql_query_for(:workItemDescriptionTemplateContent,
        { templateContentInput: { projectId: project.id, name: "project_issues_template_a" } })
    end

    let_it_be(:group_default_template_files) do
      {
        ".gitlab/issue_templates/project_issues_template_a.md" => "group default content"
      }
    end

    let_it_be(:group_default_template_project) do
      create(:project, :custom_repo, files: group_default_template_files, group: group)
    end

    before do
      create(:namespace_template_setting, namespace: group, file_template_project_id: group_default_template_project.id)
    end

    it 'returns the template from the specified project' do
      post_graphql(query, current_user: current_user)

      expect(expected_graphql_data["projectId"]).to eq(project.id.to_s)
      expect(expected_graphql_data["name"]).to eq("project_issues_template_a")
      expect(expected_graphql_data["category"]).to be_nil
      expect(expected_graphql_data["content"]).to eq("project_issues_template_a content")

      expect(response).to have_gitlab_http_status(:ok)
      expect(graphql_errors).to be_nil
    end
  end
end
