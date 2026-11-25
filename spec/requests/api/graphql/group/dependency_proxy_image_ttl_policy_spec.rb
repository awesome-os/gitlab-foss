# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'getting dependency proxy image ttl policy for a group', feature_category: :virtual_registry do
  using RSpec::Parameterized::TableSyntax
  include GraphqlHelpers

  let_it_be(:user) { create(:user) }
  let_it_be_with_reload(:group) { create(:group) }

  let(:dependency_proxy_image_ttl_policy_fields) do
    <<~GQL
      #{all_graphql_fields_for('dependency_proxy_image_ttl_group_policy'.classify, max_depth: 1)}
    GQL
  end

  let(:fields) do
    <<~GQL
      #{query_graphql_field('dependency_proxy_image_ttl_policy', {}, dependency_proxy_image_ttl_policy_fields)}
    GQL
  end

  let(:query) do
    graphql_query_for(
      'group',
      { 'fullPath' => group.full_path },
      fields
    )
  end

  let(:variables) { {} }
  let(:dependency_proxy_image_ttl_policy_response) { graphql_data.dig('group', 'dependencyProxyImageTtlPolicy') }

  before do
    stub_config(dependency_proxy: { enabled: true })
  end

  subject { post_graphql(query, current_user: user, variables: variables) }

  it_behaves_like 'a working graphql query' do
    before do
      subject
    end
  end

  context 'with different permissions' do
    where(:group_visibility, :role, :access_granted) do
      :private | :owner      | true
      :private | :maintainer | false
      :private | :developer  | false
      :private | :reporter   | false
      :private | :guest      | false
      :private | :anonymous  | false

      :public  | :owner      | true
      :public  | :maintainer | false
      :public  | :developer  | false
      :public  | :reporter   | false
      :public  | :guest      | false
      :public  | :anonymous  | false
    end

    with_them do
      before do
        group.update_column(:visibility_level, Gitlab::VisibilityLevel.const_get(group_visibility.to_s.upcase, false))
        group.add_member(user, role) unless role == :anonymous
      end

      it 'return the proper response' do
        subject

        if access_granted
          expect(dependency_proxy_image_ttl_policy_response).to eq("createdAt" => nil, "enabled" => false, "ttl" => 90, "updatedAt" => nil)
        else
          expect(dependency_proxy_image_ttl_policy_response).to be_blank
        end
      end
    end
  end

  context 'with a fine-grained personal access token' do
    before_all do
      group.add_owner(user)
    end

    let(:boundary_object) { group }
    let(:request) { post_graphql(query, token: { personal_access_token: pat }) }

    it_behaves_like 'authorizing granular token permissions for GraphQL with a skipped child type',
      [:read_group, :read_dependency_proxy_setting] do
      let(:skipped_data_path) { %i[group dependencyProxyImageTtlPolicy] }
    end

    it_behaves_like 'denying a granular token that only authorizes the parent of a field', :read_group do
      let(:parent_data_path) { %i[group] }
      let(:field_data_path) { %i[group dependencyProxyImageTtlPolicy] }
    end

    it_behaves_like 'denying a granular token that only authorizes the parent of a field',
      [:read_group, :read_dependency_proxy] do
      let(:parent_data_path) { %i[group] }
      let(:field_data_path) { %i[group dependencyProxyImageTtlPolicy] }
    end
  end
end
