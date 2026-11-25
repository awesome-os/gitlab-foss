# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Root namespace response header', feature_category: :rate_limiting do
  include ApiHelpers

  let_it_be(:group) { create(:group, :public) }
  let_it_be(:subgroup) { create(:group, :public, parent: group) }

  def header
    response.headers[Gitlab::Middleware::RequestCost::HEADER_NAMESPACE]
  end

  it 'is returned on an API request' do
    get api("/groups/#{subgroup.id}")

    expect(response).to have_gitlab_http_status(:ok)
    expect(header).to eq(group.path)
  end

  it 'is returned on a page' do
    get group_path(subgroup)

    expect(response).to have_gitlab_http_status(:ok)
    expect(header).to eq(group.path)
  end

  it 'is not returned on a request without a namespace' do
    get new_user_session_path

    expect(response).to have_gitlab_http_status(:ok)
    expect(header).to be_nil
  end

  context 'when root_namespace_response_header is disabled' do
    before do
      stub_feature_flags(root_namespace_response_header: false)
    end

    it 'is not returned' do
      get api("/groups/#{subgroup.id}")

      expect(response).to have_gitlab_http_status(:ok)
      expect(header).to be_nil
    end
  end
end
