# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::Repositories, feature_category: :source_code_management do
  let_it_be(:user) { create(:user) }
  let_it_be(:project, reload: true) { create(:project, :repository, creator: user) }
  let!(:maintainer) { create(:project_member, :maintainer, user: user, project: project) }
  let(:guest) { create(:user).tap { |u| create(:project_member, :guest, user: u, project: project) } }

  describe 'GET :id/repository/merge_base' do
    let(:refs) do
      %w[304d257dcb821665ab5110318fc58a007bd104ed 0031876facac3f2b2702a0e53a26e89939a42209 570e7b2abdd848b95f2f578043fc23bd6f6fd24d]
    end

    subject(:request) do
      get(api("/projects/#{project.id}/repository/merge_base", current_user), params: { refs: refs })
    end

    shared_examples 'merge base' do
      it 'returns the common ancestor' do
        request

        expect(response).to have_gitlab_http_status(:success)
        expect(json_response['id']).to be_present
      end
    end

    context 'when unauthenticated', 'and project is public' do
      it_behaves_like 'merge base' do
        let(:project) { create(:project, :public, :repository) }
        let(:current_user) { nil }
      end
    end

    context 'when unauthenticated', 'and project is private' do
      it_behaves_like '404 response' do
        let(:current_user) { nil }
        let(:message) { '404 Project Not Found' }
      end
    end

    context 'when authenticated', 'as a developer' do
      it_behaves_like 'merge base' do
        let(:current_user) { user }
      end
    end

    context 'when authenticated', 'as a guest' do
      it_behaves_like '403 response' do
        let(:current_user) { guest }
      end
    end

    context 'when passing refs that do not exist' do
      it_behaves_like '400 response' do
        let(:refs) { %w[304d257dcb821665ab5110318fc58a007bd104ed missing] }
        let(:current_user) { user }
        let(:message) { 'Could not find ref: missing' }
      end
    end

    context 'when both refs do not exist' do
      it_behaves_like '400 response' do
        let(:refs) { %w[first-missing second-missing] }
        let(:current_user) { user }
        let(:message) { 'Could not find refs: first-missing, second-missing' }
      end
    end

    context 'when several of multiple refs do not exist' do
      it_behaves_like '400 response' do
        let(:refs) do
          %w[first-missing 304d257dcb821665ab5110318fc58a007bd104ed second-missing]
        end

        let(:current_user) { user }
        let(:message) { 'Could not find refs: first-missing, second-missing' }
      end
    end

    context 'when passing refs that do not have a merge base' do
      it_behaves_like '404 response' do
        let(:refs) { ['304d257dcb821665ab5110318fc58a007bd104ed', TestEnv::BRANCH_SHA['orphaned-branch']] }
        let(:current_user) { user }
        let(:message) { '404 Merge Base Not Found' }
      end
    end

    context 'when not enough refs are passed' do
      let(:refs) { %w[only-one] }
      let(:current_user) { user }

      it 'renders a bad request error' do
        request

        expect(response).to have_gitlab_http_status(:bad_request)
        expect(json_response['message']).to eq('Provide at least 2 refs')
      end
    end

    it_behaves_like 'authorizing granular token permissions', :read_repository_merge_base do
      let(:boundary_object) { project }
      let(:request) do
        get api("/projects/#{project.id}/repository/merge_base", personal_access_token: pat), params: { refs: refs }
      end
    end
  end
end
