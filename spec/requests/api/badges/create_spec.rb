# frozen_string_literal: true

require 'spec_helper'

# rubocop:disable RSpec/SpecFilePathFormat -- one file per badges endpoint, split from badges_spec.rb to keep CI jobs short
RSpec.describe API::Badges, feature_category: :groups_and_projects do
  include_context 'with API badges setup'

  shared_examples 'POST /:sources/:id/badges' do |source_type|
    include_context 'source helpers'

    let(:source) { get_source(source_type) }
    let(:example_name) { 'BadgeName' }
    let(:example_url) { 'http://www.example.com' }
    let(:example_url2) { 'http://www.example1.com' }

    context "with :sources == #{source_type.pluralize}" do
      it_behaves_like 'a 404 response when source is private' do
        let(:route) do
          post api("/#{source_type.pluralize}/#{source.id}/badges", stranger),
            params: { name: example_name, link_url: example_url, image_url: example_url2 }
        end
      end

      context 'when authenticated as a non-member or member with insufficient rights' do
        %i[access_requester stranger developer].each do |type|
          context "as a #{type}" do
            it 'returns 403' do
              user = public_send(type)

              post api("/#{source_type.pluralize}/#{source.id}/badges", user),
                params: { link_url: example_url, image_url: example_url2 }

              expect(response).to have_gitlab_http_status(:forbidden)
            end
          end
        end
      end

      context 'when authenticated as a maintainer/owner' do
        it 'creates a new badge' do
          expect do
            post api("/#{source_type.pluralize}/#{source.id}/badges", maintainer),
              params: { name: example_name, link_url: example_url, image_url: example_url2 }

            expect(response).to have_gitlab_http_status(:created)
          end.to change { source.badges.count }.by(1)

          expect(json_response['name']).to eq(example_name)
          expect(json_response['link_url']).to eq(example_url)
          expect(json_response['image_url']).to eq(example_url2)
          expect(json_response['kind']).to eq source_type
        end
      end

      it 'returns 400 when link_url is not given' do
        post api("/#{source_type.pluralize}/#{source.id}/badges", maintainer),
          params: { link_url: example_url }

        expect(response).to have_gitlab_http_status(:bad_request)
      end

      it 'returns 400 when image_url is not given' do
        post api("/#{source_type.pluralize}/#{source.id}/badges", maintainer),
          params: { image_url: example_url2 }

        expect(response).to have_gitlab_http_status(:bad_request)
      end

      it 'returns 400 when link_url or image_url is not valid' do
        post api("/#{source_type.pluralize}/#{source.id}/badges", maintainer),
          params: { link_url: 'whatever', image_url: 'whatever' }

        expect(response).to have_gitlab_http_status(:bad_request)
      end
    end

    it_behaves_like 'authorizing granular token permissions', :create_badge do
      let(:user) { developer }
      let(:boundary_object) { source }
      let!(:source_setup) { source.add_owner(user) }
      let(:request) do
        post api("/#{source_type.pluralize}/#{source.id}/badges", personal_access_token: pat),
          params: { name: example_name, link_url: example_url, image_url: example_url2 }
      end
    end
  end

  describe 'Endpoints' do
    %w[project group].each do |source_type|
      it_behaves_like 'POST /:sources/:id/badges', source_type
    end
  end
end
# rubocop:enable RSpec/SpecFilePathFormat
