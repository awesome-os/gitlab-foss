# frozen_string_literal: true

require 'spec_helper'

# rubocop:disable RSpec/SpecFilePathFormat -- one file per badges endpoint, split from badges_spec.rb to keep CI jobs short
RSpec.describe API::Badges, feature_category: :groups_and_projects do
  include_context 'with API badges setup'

  shared_examples 'GET /:sources/:id/badges/render' do |source_type|
    include_context 'source helpers'

    let(:source) { get_source(source_type) }
    let(:example_url) { 'http://www.example.com/test?key=Test White Space' }
    let(:example_url2) { 'http://www.example1.com/test?key=Test White Space' }

    context "with :sources == #{source_type.pluralize}" do
      it_behaves_like 'a 404 response when source is private' do
        let(:route) do
          get api("/#{source_type.pluralize}/#{source.id}/badges/render?link_url=#{example_url}&image_url=#{example_url2}", stranger)
        end
      end

      context 'when authenticated as a non-member or member with insufficient rights' do
        %i[access_requester stranger developer].each do |type|
          context "as a #{type}" do
            it 'returns 403' do
              user = public_send(type)

              get api("/#{source_type.pluralize}/#{source.id}/badges/render?link_url=#{example_url}&image_url=#{example_url2}", user)

              expect(response).to have_gitlab_http_status(:forbidden)
            end
          end
        end
      end

      context 'when authenticated as a maintainer/owner' do
        it 'gets the rendered badge values' do
          get api("/#{source_type.pluralize}/#{source.id}/badges/render?link_url=#{example_url}&image_url=#{example_url2}", maintainer)

          expect(response).to have_gitlab_http_status(:ok)

          expect(json_response.keys).to contain_exactly('name', 'link_url', 'rendered_link_url', 'image_url', 'rendered_image_url')
          expect(json_response['link_url']).to eq(example_url)
          expect(json_response['image_url']).to eq(example_url2)
          expect(json_response['rendered_link_url']).to eq(Addressable::URI.escape(example_url))
          expect(json_response['rendered_image_url']).to eq(Addressable::URI.escape(example_url2))
        end
      end

      it 'returns 400 when link_url is not given' do
        get api("/#{source_type.pluralize}/#{source.id}/badges/render?link_url=#{example_url}", maintainer)

        expect(response).to have_gitlab_http_status(:bad_request)
      end

      it 'returns 400 when image_url is not given' do
        get api("/#{source_type.pluralize}/#{source.id}/badges/render?image_url=#{example_url}", maintainer)

        expect(response).to have_gitlab_http_status(:bad_request)
      end

      it 'returns 400 when link_url or image_url is not valid' do
        get api("/#{source_type.pluralize}/#{source.id}/badges/render?link_url=whatever&image_url=whatever", maintainer)

        expect(response).to have_gitlab_http_status(:bad_request)
      end
    end

    it_behaves_like 'authorizing granular token permissions', :read_badge do
      let(:user) { developer }
      let(:boundary_object) { source }
      let!(:source_setup) { source.add_owner(user) }
      let(:request) do
        get api("/#{source_type.pluralize}/#{source.id}/badges/render?link_url=#{example_url}&image_url=#{example_url2}", personal_access_token: pat)
      end
    end
  end

  describe 'Endpoints' do
    %w[project group].each do |source_type|
      it_behaves_like 'GET /:sources/:id/badges/render', source_type
    end
  end
end
# rubocop:enable RSpec/SpecFilePathFormat
