# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Onboarding::FeatureLibraryController, feature_category: :onboarding do
  using RSpec::Parameterized::TableSyntax

  let_it_be(:user) { create(:user) }

  describe 'GET /-/onboarding/feature_library/search', :clean_gitlab_redis_rate_limiting do
    context 'when signed in' do
      before do
        sign_in(user)
      end

      it 'returns 200 with a non-empty ids array for a valid request', :aggregate_failures do
        get onboarding_feature_library_search_path, params: { query: 'pr', panel: 'project' }

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response['ids']).to be_an(Array).and include('project_merge_request_list')
      end

      context 'with an invalid panel' do
        it 'returns an empty ids array', :aggregate_failures do
          get onboarding_feature_library_search_path, params: { query: 'pr', panel: 'invalid' }

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response['ids']).to eq([])
        end
      end

      context 'when the query parameter is missing' do
        it 'returns an empty ids array', :aggregate_failures do
          get onboarding_feature_library_search_path, params: { panel: 'project' }

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response['ids']).to eq([])
        end
      end

      context 'when the rate limit is exceeded' do
        before do
          allow(Gitlab::ApplicationRateLimiter)
            .to receive(:throttled_request?)
            .with(anything, anything, :feature_library_search, scope: { user: user })
            .and_return(true)
        end

        it 'returns 429 with a JSON error message', :aggregate_failures do
          get onboarding_feature_library_search_path, params: { query: 'pr', panel: 'project' }

          expect(response).to have_gitlab_http_status(:too_many_requests)
          expect(json_response['error']).to be_present
        end
      end

      context 'when the query exceeds MAX_QUERY_LENGTH' do
        let(:long_query) { 'x' * (described_class::MAX_QUERY_LENGTH + 50) }

        it 'truncates the query to MAX_QUERY_LENGTH before searching' do
          expect(Onboarding::FeatureLibrary::FeatureMatchService)
            .to receive(:new)
            .with(a_hash_including(query: 'x' * described_class::MAX_QUERY_LENGTH, panel: 'project'))
            .and_call_original

          get onboarding_feature_library_search_path, params: { query: long_query, panel: 'project' }

          expect(response).to have_gitlab_http_status(:ok)
        end
      end

      context 'when the query is exactly MAX_QUERY_LENGTH' do
        let(:max_query) { 'x' * described_class::MAX_QUERY_LENGTH }

        it 'passes the query through unchanged' do
          expect(Onboarding::FeatureLibrary::FeatureMatchService)
            .to receive(:new)
            .with(a_hash_including(query: max_query, panel: 'project'))
            .and_call_original

          get onboarding_feature_library_search_path, params: { query: max_query, panel: 'project' }

          expect(response).to have_gitlab_http_status(:ok)
        end
      end

      context 'when not authenticated' do
        before do
          sign_out(user)
        end

        it 'redirects to sign in' do
          get onboarding_feature_library_search_path, params: { query: 'pr', panel: 'project' }

          expect(response).to redirect_to(new_user_session_path)
        end
      end
    end
  end

  describe 'GET /-/onboarding/feature_library/catalog', :clean_gitlab_redis_rate_limiting do
    let_it_be(:group) { create(:group, developers: user) }

    let(:params) { { panel: 'group', resource_id: group.id } }

    subject(:request) { get onboarding_feature_library_catalog_path, params: params }

    before do
      sign_in(user)
    end

    shared_context 'with the documentation URL on another host' do
      before do
        stub_application_setting(help_page_documentation_base_url: 'https://docs.example.com')
        stub_config(gitlab_docs: { enabled: false })
      end
    end

    # EE builds the CTA from the license, so its payload is covered in the EE request spec.
    context 'in CE', unless: Gitlab.ee? do
      it 'returns both pages on Free, with the migration notice and no CTA for a non-admin', :aggregate_failures do
        request

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response['current_plan_context']).to include('base_plan' => 'free')
        expect(json_response['pages'].pluck('plan')).to eq(%w[premium ultimate])
        expect(json_response['pages'].pluck('notice'))
          .to all(include('url' => 'https://about.gitlab.com/gitlab-community-edition/'))
        expect(json_response['pages'].pluck('cta')).to all(be_nil)
      end

      context 'when the user is an admin', :enable_admin_mode do
        let_it_be(:admin) { create(:admin) }

        before do
          sign_in(admin)
        end

        it 'offers Migrate to Enterprise Edition on every page' do
          request

          expect(json_response['pages'].pluck('cta')).to all(include(
            'type' => 'migrate',
            'url' => '/help/update/convert_to_ee/_index.md#convert-to-enterprise-edition',
            'new_tab' => true
          ))
        end

        context 'when the documentation URL points at another host' do
          include_context 'with the documentation URL on another host'

          it 'redirects Migrate to Enterprise Edition to the conversion docs there' do
            request

            get json_response['pages'].first['cta']['url'].split('#').first

            expect(response).to redirect_to(%r{\Ahttps://docs\.example\.com/.*update/convert_to_ee/\z})
          end
        end
      end
    end

    context 'when the documentation URL points at another host' do
      include_context 'with the documentation URL on another host'

      it 'redirects Learn more there' do
        request

        get json_response['pages'].first['highlights'].first['docs_url']

        expect(response).to redirect_to(%r{\Ahttps://docs\.example\.com/})
      end
    end

    context 'when the rate limit is exceeded' do
      before do
        allow(Gitlab::ApplicationRateLimiter)
          .to receive(:throttled_request?)
          .with(anything, anything, :feature_library_catalog, scope: { user: user })
          .and_return(true)
      end

      it 'returns 429 with a JSON error message', :aggregate_failures do
        request

        expect(response).to have_gitlab_http_status(:too_many_requests)
        expect(json_response['error']).to be_present
      end
    end

    context 'when not authenticated' do
      before do
        sign_out(user)
      end

      it 'redirects to sign in' do
        request

        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe 'GET /-/onboarding/feature_library/catalog access and payload', :clean_gitlab_redis_rate_limiting do
    let_it_be(:group) { create(:group, developers: user) }
    let_it_be(:project) { create(:project, group: group) }
    let_it_be(:private_project) { create(:project, :private) }

    let(:params) { { panel: 'project', resource_id: project.id } }

    subject(:request) { get onboarding_feature_library_catalog_path, params: params }

    before do
      sign_in(user)
    end

    it 'returns the plan context and both pages', :aggregate_failures do
      request

      expect(response).to have_gitlab_http_status(:ok)
      expect(json_response['current_plan_context']).to include('current_plan', 'base_plan', 'deployment', 'trial')
      expect(json_response['pages'].pluck('plan')).to eq(%w[premium ultimate])
      expect(json_response['pages']).to all(include('plan', 'notice', 'cta', 'highlights', 'credits', 'categories'))
    end

    it 'serializes items with the contract keys', :aggregate_failures do
      request

      item = json_response['pages'].first['categories'].first['items'].first

      expect(item.keys).to contain_exactly('id', 'source', 'title', 'description', 'icon', 'docs_url', 'label')
      expect(item['source']).to eq('nav_item')
      expect(item['docs_url']).to start_with('/help/')
      expect(item['label']).to include('type' => be_in(%w[new enhanced add_on]), 'plan' => 'premium')
    end

    context 'with a group panel' do
      let(:params) { { panel: 'group', resource_id: group.id } }

      it 'returns the group pages' do
        request

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response['pages'].pluck('plan')).to eq(%w[premium ultimate])
      end
    end

    context 'when the flag is enabled for a different root namespace' do
      before do
        stub_feature_flags(feature_catalog_explore_pages: create(:group))
      end

      it 'returns 404' do
        request

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context 'when the resource is missing' do
      let(:params) { { panel: 'project' } }

      it 'returns 404' do
        request

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context 'when the user cannot read the resource' do
      let(:params) { { panel: 'project', resource_id: private_project.id } }

      it 'returns 404' do
        request

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context 'when the user can read the resource but is not a member' do
      let_it_be(:public_group) { create(:group, :public) }
      let_it_be(:public_project) { create(:project, :public, group: public_group) }

      where(:panel, :resource) do
        'group'   | ref(:public_group)
        'project' | ref(:public_project)
      end

      with_them do
        let(:params) { { panel: panel, resource_id: resource.id } }

        it 'returns 404' do
          request

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end

      context 'when the user is an admin' do
        let_it_be(:admin) { create(:admin) }
        let(:params) { { panel: 'group', resource_id: public_group.id } }

        before do
          sign_in(admin)
        end

        it 'returns 404 without admin mode' do
          request

          expect(response).to have_gitlab_http_status(:not_found)
        end

        context 'with admin mode', :enable_admin_mode do
          it 'returns the pages' do
            request

            expect(response).to have_gitlab_http_status(:ok)
          end
        end
      end
    end

    context 'with an invalid panel' do
      let(:params) { { panel: 'invalid', resource_id: project.id } }

      it 'returns 422' do
        request

        expect(response).to have_gitlab_http_status(:unprocessable_entity)
      end
    end
  end
end
