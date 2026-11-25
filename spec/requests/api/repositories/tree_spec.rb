# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::Repositories, feature_category: :source_code_management do
  let_it_be(:user) { create(:user) }
  let_it_be(:project, reload: true) { create(:project, :repository, creator: user) }
  let!(:maintainer) { create(:project_member, :maintainer, user: user, project: project) }
  let(:guest) { create(:user).tap { |u| create(:project_member, :guest, user: u, project: project) } }

  describe "GET /projects/:id/repository/tree" do
    let(:route) { "/projects/#{project.id}/repository/tree" }

    shared_examples_for 'repository tree' do
      it 'returns the repository tree' do
        get api(route, current_user)

        expect(response).to have_gitlab_http_status(:ok)
        expect(response).to include_pagination_headers
        expect(json_response).to be_an(Array)

        first_commit = json_response.first
        expect(first_commit['name']).to eq('bar')
        expect(first_commit['type']).to eq('tree')
        expect(first_commit['mode']).to eq('040000')
      end

      context 'when ref does not exist' do
        it_behaves_like '404 response' do
          let(:request) { get api("#{route}?ref=foo", current_user) }
          let(:message) { '404 Tree Not Found' }
        end
      end

      context 'when path does not exist' do
        let(:path) { 'bogus' }

        it_behaves_like '404 response' do
          let(:request) { get api("#{route}?path=#{path}", current_user) }
          let(:message) { '404 invalid revision or path Not Found' }
        end
      end

      context 'when repository is disabled' do
        include_context 'disabled repository'

        it_behaves_like '403 response' do
          let(:request) { get api(route, current_user) }
        end
      end

      context 'with recursive=1' do
        it 'returns recursive project paths tree' do
          get api("#{route}?recursive=1", current_user)

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response).to be_an Array
          expect(response).to include_pagination_headers
          expect(json_response[4]['name']).to eq('html')
          expect(json_response[4]['path']).to eq('files/html')
          expect(json_response[4]['type']).to eq('tree')
          expect(json_response[4]['mode']).to eq('040000')
        end

        context 'when repository is disabled' do
          include_context 'disabled repository'

          it_behaves_like '403 response' do
            let(:request) { get api(route, current_user) }
          end
        end

        context 'when ref does not exist' do
          it_behaves_like '404 response' do
            let(:request) { get api("#{route}?recursive=1&ref=foo", current_user) }
            let(:message) { '404 Tree Not Found' }
          end
        end
      end

      context 'keyset pagination mode' do
        let(:first_response) do
          get api(route, current_user), params: { pagination: "keyset" }

          Gitlab::Json.parse(response.body)
        end

        it 'paginates using keysets' do
          page_token = first_response.last["id"]

          get api(route, current_user), params: { pagination: "keyset", page_token: page_token }

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response).to be_an(Array)
          expect(json_response).not_to eq(first_response)
          expect(json_response.map { |t| t["id"] }).not_to include(page_token)
        end
      end

      context 'with pagination=none' do
        context 'with recursive=1' do
          it 'returns unpaginated recursive project paths tree' do
            get api("#{route}?recursive=1&pagination=none", current_user)

            expect(response).to have_gitlab_http_status(:ok)
            expect(json_response).to be_an Array
            expect(response).not_to include_pagination_headers
            expect(json_response[4]['name']).to eq('html')
            expect(json_response[4]['path']).to eq('files/html')
            expect(json_response[4]['type']).to eq('tree')
            expect(json_response[4]['mode']).to eq('040000')
          end
        end

        context 'with recursive=0' do
          it 'returns 400' do
            get api("#{route}?recursive=0&pagination=none", current_user)

            expect(response).to have_gitlab_http_status(:bad_request)
            expect(json_response['error'])
              .to eq('pagination cannot be "none" unless "recursive" is true')
          end
        end
      end

      context 'with with_last_commit=true' do
        it 'includes the last commit for each tree entry' do
          get api(route, current_user), params: { with_last_commit: true }

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response).to be_an(Array)

          expect(json_response).to be_present
          expect(json_response).to all(include('last_commit'))
          json_response.each do |entry|
            expect(entry['last_commit']['id']).to be_present
            expect(entry['last_commit']['message']).to be_present
          end
        end

        it 'does not scale the number of queries with the number of entries' do
          control = ActiveRecord::QueryRecorder.new do
            get api(route, current_user), params: { with_last_commit: true, per_page: 5 }
          end

          expect do
            get api(route, current_user), params: { with_last_commit: true, per_page: 20 }
          end.not_to exceed_query_limit(control)
        end

        it 'returns 400 when combined with recursive' do
          get api(route, current_user), params: { with_last_commit: true, recursive: true }

          expect(response).to have_gitlab_http_status(:bad_request)
          expect(json_response['error'])
            .to eq('recursive cannot be "true" when "with_last_commit" is "true"')
        end
      end
    end

    context 'with legacy pagination when authenticated as a maintainer' do
      let(:files) do
        {
          'Foo/x' => 'content',
          'Foo.A/x' => 'content',
          'Foo.A.Test/x' => 'content'
        }
      end

      let(:project) { create(:project, :custom_repo, creator: user, files: files) }

      it 'returns every entry once in trees-first filesystem order across pages' do
        get api(route, user), params: { page: 1, per_page: 2 }
        first_page_names = json_response.pluck('name')

        get api(route, user), params: { page: 2, per_page: 2 }
        second_page_names = json_response.pluck('name')

        expect([first_page_names, second_page_names]).to eq([%w[Foo Foo.A], %w[Foo.A.Test]])
      end
    end

    context 'with legacy pagination of later pages', :use_clean_rails_memory_store_caching do
      let(:per_page) { 10 }
      let(:max_pages) { 100 }
      let(:recursive) { true }
      let(:pagination_headers) { %w[X-Page X-Per-Page X-Next-Page X-Prev-Page X-Total X-Total-Pages Link] }

      def read_pages
        pages = []
        page = 1

        while page
          raise 'too many pages' if pages.size > max_pages

          get api(route, user), params: { recursive: recursive, per_page: per_page, page: page }
          pages << { paths: json_response.pluck('path'), headers: pagination_headers_of(response) }
          page = response.headers['X-Next-Page'].presence
        end

        pages
      end

      # The api helper signs every request with a new token, which ends up in the Link header.
      def pagination_headers_of(response)
        headers = response.headers.slice(*pagination_headers)
        headers.merge('Link' => headers['Link'].gsub(/private_token=[^&>]*&?/, ''))
      end

      def read_keyset_pages
        pages = []
        params = { recursive: recursive, per_page: per_page, pagination: 'keyset' }

        while params
          raise 'too many pages' if pages.size > max_pages

          get api(route, user), params: params
          pages << json_response.pluck('path')
          next_link = response.headers['Link'].to_s[/<([^>]+)>; rel="next"/, 1]
          params = next_link && Rack::Utils.parse_query(URI.parse(next_link).query)
        end

        pages
      end

      it 'returns the same entries and headers as without the offset', :aggregate_failures do
        stub_feature_flags(tree_offset_pagination_gitaly_offset: false)
        without_offset = read_pages

        stub_feature_flags(tree_offset_pagination_gitaly_offset: true)
        with_offset = read_pages

        expect(with_offset.size).to be > 2
        expect(with_offset.pluck(:headers)).to eq(without_offset.pluck(:headers))
        expect(with_offset.flat_map { |page| page[:paths] })
          .to match_array(without_offset.flat_map { |page| page[:paths] })
      end

      it 'returns the pages in the order of keyset pagination' do
        expect(read_pages.pluck(:paths)).to eq(read_keyset_pages)
      end

      it 'reads the whole tree only once, for the cached total' do
        allow(Gitlab::Git::Tree).to receive(:tree_entries).and_call_original

        read_pages

        expect(Gitlab::Git::Tree).to have_received(:tree_entries)
          .with(hash_including(pagination_params: nil)).once
      end

      context 'with a page after the last one' do
        def read_past_last_page
          get api(route, user), params: { recursive: recursive, per_page: per_page, page: read_pages.size + 1 }

          { status: response.status, body: json_response, headers: pagination_headers_of(response) }
        end

        it 'returns an empty page with the same headers as without the offset', :aggregate_failures do
          stub_feature_flags(tree_offset_pagination_gitaly_offset: false)
          without_offset = read_past_last_page

          stub_feature_flags(tree_offset_pagination_gitaly_offset: true)
          with_offset = read_past_last_page

          expect(with_offset[:status]).to eq(200)
          expect(with_offset[:body]).to eq([])
          expect(with_offset).to eq(without_offset)
        end

        it 'does not read the tree for it' do
          last_page = read_pages.size

          expect(Gitlab::Git::Tree).not_to receive(:tree_entries)

          get api(route, user), params: { recursive: recursive, per_page: per_page, page: last_page + 1 }
        end
      end

      it 'returns 404 for a later page of a missing path' do
        get api(route, user), params: { path: 'missing', recursive: recursive, per_page: per_page, page: 2 }

        expect(response).to have_gitlab_http_status(:not_found)
      end

      context 'with a non-recursive tree' do
        let(:recursive) { false }
        let(:per_page) { 3 }

        it 'returns the same entries and headers as without the offset', :aggregate_failures do
          stub_feature_flags(tree_offset_pagination_gitaly_offset: false)
          without_offset = read_pages

          stub_feature_flags(tree_offset_pagination_gitaly_offset: true)
          with_offset = read_pages

          expect(with_offset.size).to be > 2
          expect(with_offset).to eq(without_offset)
        end
      end

      context 'when Git and Gitaly sort the directories differently' do
        let(:per_page) { 2 }
        let(:project) do
          create(:project, :custom_repo, creator: user, files: { 'foo/x' => '', 'foo-bar/x' => '', 'foo.a/x' => '' })
        end

        it 'returns every entry once', :aggregate_failures do
          paths = read_pages.pluck(:paths)

          expect(paths.flatten).to contain_exactly('foo', 'foo-bar', 'foo.a', 'foo/x', 'foo-bar/x', 'foo.a/x')
          expect(paths).to eq(read_keyset_pages)
        end
      end
    end

    context 'when unauthenticated', 'and project is public' do
      it_behaves_like 'repository tree' do
        let_it_be_with_reload(:project) { create(:project, :public, :repository) }
        let(:current_user) { nil }
      end
    end

    context 'when unauthenticated', 'and project is private' do
      it_behaves_like '404 response' do
        let(:request) { get api(route) }
        let(:message) { '404 Project Not Found' }
      end
    end

    context 'when authenticated', 'as a developer' do
      it_behaves_like 'repository tree' do
        let(:current_user) { user }
      end
    end

    context 'when authenticated', 'as a guest' do
      it_behaves_like '403 response' do
        let(:request) { get api(route, guest) }
      end
    end

    context 'when authenticated using a token with ai_workflows scope' do
      let(:oauth_token) { create(:oauth_access_token, user: user, scopes: [:ai_workflows]) }

      it 'returns repository tree' do
        get api(route, oauth_access_token: oauth_token)

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response).to be_an(Array)
      end
    end

    it_behaves_like 'authorizing granular token permissions', :read_repository_tree do
      let(:boundary_object) { project }
      let(:request) do
        get api(route, personal_access_token: pat)
      end
    end
  end
end
