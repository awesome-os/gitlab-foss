# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RedirectsForMissingPathOnTree do
  controller(ActionController::Base) do
    include Gitlab::Routing.url_helpers
    include RedirectsForMissingPathOnTree

    def fake
      redirect_to_tree_root_for_missing_path(Project.find(params[:project_id]), params[:ref], params[:file_path])
    end
  end

  let(:project) { create(:project) }

  before do
    routes.draw { get 'fake' => 'anonymous#fake' }
  end

  describe '#redirect_to_root_path' do
    it 'redirects to the tree path with a notice' do
      long_file_path = ('a/b/' * 30) + 'foo.txt'
      truncated_file_path = '...b/' + ('a/b/' * 12) + 'foo.txt'
      expected_message = "<code>#{truncated_file_path}</code> doesn&#39;t exist on " \
        '<strong class="ref-name">theref</strong>, so you&#39;re viewing the root of ' \
        '<strong class="ref-name">theref</strong>.'

      get :fake, params: { project_id: project.id, ref: 'theref', file_path: long_file_path }

      expect(response).to redirect_to project_tree_path(project, 'theref')
      expect(controller).to set_flash[:notice].to eq(expected_message)
    end

    it 'shows a full commit SHA as the short SHA' do
      sha = 'a' * 40

      get :fake, params: { project_id: project.id, ref: sha, file_path: 'foo.txt' }

      expect(response).to redirect_to project_tree_path(project, sha)
      expect(flash[:notice]).to include('<strong class="ref-name">aaaaaaaa</strong>')
      expect(flash[:notice]).not_to include(sha)
    end

    it 'escapes the path and ref' do
      get :fake, params: { project_id: project.id, ref: '<b>ref</b>', file_path: '<i>x</i>' }

      expect(flash[:notice]).to include('<code>&lt;i&gt;x&lt;/i&gt;</code>')
      expect(flash[:notice]).to include('&lt;b&gt;ref&lt;/b&gt;')
    end
  end
end
