# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'User custom attributes', feature_category: :user_profile do
  include GraphqlHelpers

  let_it_be(:admin) { create(:admin) }
  let_it_be(:user) { create(:user) }
  let_it_be(:target_user) { create(:user) }
  let_it_be(:custom_attribute) do
    create(:user_custom_attribute, user: target_user, key: 'department', value: 'engineering')
  end

  let(:query) do
    graphql_query_for(
      :user,
      { id: target_user.to_global_id.to_s },
      'customAttributes { key value }'
    )
  end

  context 'when user is not an admin' do
    it 'returns null for custom attributes' do
      post_graphql(query, current_user: user)

      expect(graphql_data_at(:user, :customAttributes)).to be_nil
    end
  end

  context 'when user is an admin', :enable_admin_mode do
    it 'returns custom attributes' do
      post_graphql(query, current_user: admin)

      expect(graphql_data_at(:user, :customAttributes)).to contain_exactly(
        a_hash_including('key' => 'department', 'value' => 'engineering')
      )
    end

    context 'when authenticated with a granular token' do
      # As in REST, the custom attributes of a user take the instance boundary.
      def post_with_token(additional_scopes)
        pat = create(:granular_pat, user: admin, boundary: ::Authz::Boundary.for(:user), permissions: %w[read_user],
          additional_scopes: additional_scopes)

        post_graphql(query, token: { personal_access_token: pat })
      end

      it 'returns custom attributes to a token that can read them on the instance', :aggregate_failures do
        post_with_token([{ boundary: ::Authz::Boundary.for(:instance), permissions: %w[read_custom_attribute] }])

        expect(graphql_errors).to be_nil
        expect(graphql_data_at(:user, :customAttributes)).to contain_exactly(
          a_hash_including('key' => 'department', 'value' => 'engineering')
        )
      end

      it 'does not return them to a token that can only read the user', :aggregate_failures do
        post_with_token([])

        expect(graphql_data_at(:user)).to be_present
        expect(graphql_data_at(:user, :customAttributes)).to be_blank
      end
    end
  end

  context 'when user has no custom attributes' do
    let(:query) do
      graphql_query_for(
        :user,
        { id: user.to_global_id.to_s },
        'customAttributes { key value }'
      )
    end

    it 'returns empty array', :enable_admin_mode do
      post_graphql(query, current_user: admin)

      expect(graphql_data_at(:user, :customAttributes)).to eq([])
    end
  end
end
