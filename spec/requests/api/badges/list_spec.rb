# frozen_string_literal: true

require 'spec_helper'

# rubocop:disable RSpec/SpecFilePathFormat -- one file per badges endpoint, split from badges_spec.rb to keep CI jobs short
RSpec.describe API::Badges, feature_category: :groups_and_projects do
  include_context 'with API badges setup'

  shared_examples 'GET /:sources/:id/badges' do |source_type|
    include_context 'source helpers'

    let(:source) { get_source(source_type) }

    context "with :sources == #{source_type.pluralize}" do
      it_behaves_like 'a 404 response when source is private' do
        let(:route) { get api("/#{source_type.pluralize}/#{source.id}/badges", stranger) }
      end

      %i[maintainer developer access_requester stranger].each do |type|
        context "when authenticated as a #{type}" do
          it 'returns 200' do
            user = public_send(type)
            badges_count = source_type == 'project' ? 3 : 2

            get api("/#{source_type.pluralize}/#{source.id}/badges", user)

            expect(response).to have_gitlab_http_status(:ok)
            expect(response).to include_pagination_headers
            expect(json_response).to be_an Array
            expect(json_response.size).to eq(badges_count)
          end
        end
      end

      it 'avoids N+1 queries' do
        # Establish baseline
        get api("/#{source_type.pluralize}/#{source.id}/badges", maintainer)

        control = ActiveRecord::QueryRecorder.new do
          get api("/#{source_type.pluralize}/#{source.id}/badges", maintainer)
        end

        project.add_developer(create(:user))

        expect do
          get api("/#{source_type.pluralize}/#{source.id}/badges", maintainer)
        end.not_to exceed_query_limit(control)
      end
    end

    it_behaves_like 'authorizing granular token permissions', :read_badge do
      let(:user) { developer }
      let(:boundary_object) { source }
      let!(:source_setup) { source.add_developer(user) }
      let(:request) { get api("/#{source_type.pluralize}/#{source.id}/badges", personal_access_token: pat) }
    end
  end

  describe 'Endpoints' do
    %w[project group].each do |source_type|
      it_behaves_like 'GET /:sources/:id/badges', source_type
    end
  end
end
# rubocop:enable RSpec/SpecFilePathFormat
