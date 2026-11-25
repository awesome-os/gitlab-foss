# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'import/github/status.html.haml', feature_category: :importers do
  let(:user) { build_stubbed(:user, :with_namespace) }
  let(:mount_element) { Nokogiri::HTML(rendered).at_css('#import-projects-mount-element') }

  before do
    allow(view).to receive_messages(
      current_user: user,
      oauth_token?: true,
      github_account_data: account_data
    )
  end

  context 'when the controller provides account data' do
    let(:account_data) do
      { github_login: 'octocat', github_reauthorize_path: new_import_github_path(reauthorize: true) }
    end

    it 'passes the login and the reauthorize path to the mount element' do
      render

      expect(mount_element['data-github-login']).to eq('octocat')
      expect(mount_element['data-github-reauthorize-path']).to eq(new_import_github_path(reauthorize: true))
    end
  end

  context 'when the controller provides no account data' do
    let(:account_data) { {} }

    it 'does not pass the account data to the mount element' do
      render

      expect(mount_element).to be_present
      expect(mount_element['data-github-login']).to be_nil
      expect(mount_element['data-github-reauthorize-path']).to be_nil
    end
  end
end
