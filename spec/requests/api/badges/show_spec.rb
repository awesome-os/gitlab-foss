# frozen_string_literal: true

require 'spec_helper'

# rubocop:disable RSpec/SpecFilePathFormat -- one file per badges endpoint, split from badges_spec.rb to keep CI jobs short
RSpec.describe API::Badges, feature_category: :groups_and_projects do
  include_context 'with API badges setup'

  shared_examples 'GET /:sources/:id/badges/:badge_id' do |source_type|
    include_context 'source helpers'

    let(:source) { get_source(source_type) }

    context "with :sources == #{source_type.pluralize}" do
      it_behaves_like 'a 404 response when source is private' do
        let(:route) { get api("/#{source_type.pluralize}/#{source.id}/badges/#{developer.id}", stranger) }
      end

      context 'when authenticated as a non-member' do
        %i[maintainer developer access_requester stranger].each do |type|
          context "as a #{type}" do
            let(:badge) { source.badges.first }

            it 'returns 200', :quarantine do
              user = public_send(type)

              get api("/#{source_type.pluralize}/#{source.id}/badges/#{badge.id}", user)

              expect(response).to have_gitlab_http_status(:ok)
              expect(json_response['name']).to eq(badge.name)
              expect(json_response['id']).to eq(badge.id)
              expect(json_response['link_url']).to eq(badge.link_url)
              expect(json_response['rendered_link_url']).to eq(badge.rendered_link_url)
              expect(json_response['image_url']).to eq(badge.image_url)
              expect(json_response['rendered_image_url']).to eq(badge.rendered_image_url)
              expect(json_response['kind']).to eq source_type
            end
          end
        end
      end
    end

    it_behaves_like 'authorizing granular token permissions', :read_badge do
      let(:user) { developer }
      let(:badge) { source.badges.first }
      let(:boundary_object) { source }
      let!(:source_setup) { source.add_developer(user) }
      let(:request) { get api("/#{source_type.pluralize}/#{source.id}/badges/#{badge.id}", personal_access_token: pat) }
    end
  end

  describe 'Endpoints' do
    %w[project group].each do |source_type|
      it_behaves_like 'GET /:sources/:id/badges/:badge_id', source_type
    end
  end
end
# rubocop:enable RSpec/SpecFilePathFormat
