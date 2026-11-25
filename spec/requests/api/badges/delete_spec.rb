# frozen_string_literal: true

require 'spec_helper'

# rubocop:disable RSpec/SpecFilePathFormat -- one file per badges endpoint, split from badges_spec.rb to keep CI jobs short
RSpec.describe API::Badges, feature_category: :groups_and_projects do
  include_context 'with API badges setup'

  shared_examples 'DELETE /:sources/:id/badges/:badge_id' do |source_type|
    include_context 'source helpers'

    let(:source) { get_source(source_type) }

    context "with :sources == #{source_type.pluralize}" do
      let(:badge) { source.badges.first }

      it_behaves_like 'a 404 response when source is private' do
        let(:route) { delete api("/#{source_type.pluralize}/#{source.id}/badges/#{badge.id}", stranger) }
      end

      context 'when authenticated as a non-member or member with insufficient rights' do
        %i[access_requester developer stranger].each do |type|
          context "as a #{type}" do
            it 'returns 403' do
              user = public_send(type)

              delete api("/#{source_type.pluralize}/#{source.id}/badges/#{badge.id}", user)

              expect(response).to have_gitlab_http_status(:forbidden)
            end
          end
        end
      end

      context 'when authenticated as a maintainer/owner', :quarantine do
        it 'deletes the badge' do
          expect do
            delete api("/#{source_type.pluralize}/#{source.id}/badges/#{badge.id}", maintainer)

            expect(response).to have_gitlab_http_status(:no_content)
          end.to change { source.badges.count }.by(-1)
        end

        it_behaves_like '412 response' do
          let(:request) { api("/#{source_type.pluralize}/#{source.id}/badges/#{badge.id}", maintainer) }
        end
      end

      it 'returns 404 if badge does not exist' do
        delete api("/#{source_type.pluralize}/#{source.id}/badges/123", maintainer)

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end
  end

  context 'when deleting a badge' do
    context 'and the source is a project' do
      let(:badge) { project.group.badges.first }

      it 'cannot delete badges owned by the project group' do
        expect do
          delete api("/projects/#{project.id}/badges/#{badge.id}", maintainer)

          expect(response).to have_gitlab_http_status(:not_found)
        end.not_to change { badge.reload.persisted? }
      end
    end

    it_behaves_like 'authorizing granular token permissions', :delete_badge do
      let(:user) { developer }
      let(:badge) { project.badges.first }
      let(:boundary_object) { project }
      let!(:project_setup) { project.add_maintainer(user) }
      let(:request) { delete api("/projects/#{project.id}/badges/#{badge.id}", personal_access_token: pat) }
    end

    it_behaves_like 'authorizing granular token permissions', :delete_badge do
      let(:user) { developer }
      let(:badge) { group.badges.first }
      let(:boundary_object) { group }
      let!(:group_setup) { group.add_owner(user) }
      let(:request) { delete api("/groups/#{group.id}/badges/#{badge.id}", personal_access_token: pat) }
    end
  end

  describe 'Endpoints' do
    %w[project group].each do |source_type|
      it_behaves_like 'DELETE /:sources/:id/badges/:badge_id', source_type
    end
  end
end
# rubocop:enable RSpec/SpecFilePathFormat
