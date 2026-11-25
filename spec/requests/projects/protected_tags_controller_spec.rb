# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Projects::ProtectedTagsController, feature_category: :source_code_management do
  describe "GET #index" do
    let_it_be(:project) { create(:project) }
    let_it_be(:user) { create(:user, maintainer_of: project) }

    before do
      sign_in(user)
    end

    it "redirects to the repository settings page" do
      get project_protected_tags_path(project)

      expect(response).to redirect_to(project_settings_repository_path(project))
    end
  end

  describe "GET #show" do
    let_it_be_with_reload(:project) { create(:project, :repository) }
    let(:user) { create(:user, maintainer_of: project) }
    let(:protected_tag) { create(:protected_tag, project: project, name: 'v*') }

    before do
      sign_in(user)
    end

    it_behaves_like 'hides the settings search bar' do
      subject { get project_protected_tag_path(project, protected_tag) }
    end
  end

  describe "DELETE #destroy" do
    let(:project) { create(:project) }
    let(:protected_tag) { create(:protected_tag, :developers_can_create, project: project) }
    let(:user) { create(:user) }

    before do
      project.add_maintainer(user)
      sign_in(user)
    end

    it "deletes the protected tag" do
      delete project_protected_tag_path(project, protected_tag)

      expect { ProtectedTag.find(protected_tag.id) }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  context "when a maintainer is denied the action's protected tag permission" do
    let_it_be_with_reload(:project) { create(:project, :repository) }
    let(:user) { create(:user, maintainer_of: project) }
    let(:protected_tag) { create(:protected_tag, project: project, name: 'v*') }

    before do
      sign_in(user)
      allow(Ability).to receive(:allowed?).and_call_original
      allow(Ability).to receive(:allowed?).with(user, permission, project).and_return(false)
    end

    context "for create without create_protected_tag" do
      let(:permission) { :create_protected_tag }

      it "returns not found" do
        post project_protected_tags_path(project), params: { protected_tag: { name: 'v2*' } }

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context "for index without update_protected_tag" do
      let(:permission) { :update_protected_tag }

      it "returns not found" do
        get project_protected_tags_path(project)

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context "for show without update_protected_tag" do
      let(:permission) { :update_protected_tag }

      it "returns not found" do
        get project_protected_tag_path(project, protected_tag)

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context "for update without update_protected_tag" do
      let(:permission) { :update_protected_tag }

      it "returns not found" do
        put project_protected_tag_path(project, protected_tag), params: { protected_tag: { name: 'v3*' } }

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context "for destroy without delete_protected_tag" do
      let(:permission) { :delete_protected_tag }

      it "returns not found" do
        delete project_protected_tag_path(project, protected_tag)

        expect(response).to have_gitlab_http_status(:not_found)
        expect(ProtectedTag.exists?(protected_tag.id)).to be(true)
      end
    end
  end

  context "when the user is a developer" do
    let_it_be_with_reload(:project) { create(:project, :repository) }
    let(:user) { create(:user, developer_of: project) }
    let(:protected_tag) { create(:protected_tag, project: project, name: 'v*') }

    before do
      sign_in(user)
    end

    it "returns not found for show without loading the protected tag" do
      allow_next_instance_of(described_class) do |controller|
        expect(controller).not_to receive(:find_protected_ref)
      end

      get project_protected_tag_path(project, protected_tag)

      expect(response).to have_gitlab_http_status(:not_found)
    end

    it "returns not found for destroy and keeps the protected tag" do
      delete project_protected_tag_path(project, protected_tag)

      expect(response).to have_gitlab_http_status(:not_found)
      expect(ProtectedTag.exists?(protected_tag.id)).to be(true)
    end
  end
end
