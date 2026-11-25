# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'import/github/new.html.haml', feature_category: :importers do
  let_it_be(:user) { build_stubbed(:user) }

  let(:ci_cd_only) { false }
  let(:oauth_configured) { true }
  let(:token_field_selector) { '#personal-access-token-panel [data-testid="personal-access-token-field"]' }

  before do
    allow(view).to receive_messages(
      current_user: user,
      has_ci_cd_only_params?: ci_cd_only,
      github_import_configured?: oauth_configured,
      status_import_github_path: '/import/github/status'
    )
  end

  subject(:page) { Capybara.string(render) }

  context 'with OAuth configured' do
    it 'shows the connect page with a single sign-in card' do
      expect(page).to have_css('h1', text: 'Connect with GitHub')
      expect(page).to have_content(
        'Authorize GitLab to read your GitHub repositories so you can select which to import.'
      )
      expect(page).to have_css('h2', text: 'Sign in with GitHub')
      expect(page).to have_content(
        "You'll sign in on GitHub, grant access, and return here."
      )
      expect(page).to have_link('Connect with GitHub', href: '/import/github/status')
    end

    it 'shows the GitHub icon in the heading' do
      expect(page).to have_css('h1 svg.s32')
    end

    it 'has no Cancel button' do
      expect(page).not_to have_button('Cancel')
      expect(page).not_to have_link('Cancel')
    end

    it 'hides the token form behind a collapsed accordion' do
      toggle = page.find_button('Use a personal access token instead')

      expect(toggle['aria-expanded']).to eq('false')
      expect(toggle['aria-controls']).to eq('personal-access-token-panel')
      expect(page).to have_css('#personal-access-token-panel.gl-hidden')
      expect(page).to have_css(token_field_selector, visible: :all)
      expect(page).to have_css('#personal-access-token-panel button', text: 'Continue', visible: :all)
    end
  end

  context 'with OAuth not configured' do
    let(:oauth_configured) { false }

    it 'shows the admin message and the token form, without the OAuth sign-in' do
      expect(page).to have_css('h2', text: 'Use a personal access token')
      expect(page).not_to have_content('Sign in with GitHub')
      expect(page).to have_content('Consider asking your GitLab administrator to configure')
      expect(page).not_to have_link('Connect with GitHub')
    end

    it 'renders the token form open, with no toggle' do
      expect(page).not_to have_button('Use a personal access token instead')
      expect(page).not_to have_css('#personal-access-token-panel')
      expect(page).to have_css('input[data-testid="personal-access-token-field"]')
      expect(page).to have_button('Continue')
    end
  end

  context 'with CI/CD only params' do
    let(:ci_cd_only) { true }

    it 'shows the plain token form without the card or accordion' do
      expect(page).to have_css('h1', text: 'Authenticate with GitHub')
      expect(page).not_to have_content('Sign in with GitHub')
      expect(page).not_to have_button('Use a personal access token instead')
      expect(page).not_to have_css('#personal-access-token-panel')
      expect(page).to have_field('personal_access_token')
      expect(page).to have_button('Authenticate')
      expect(page).not_to have_button('Continue')
    end

    it 'shows the GitHub icon in the heading' do
      expect(page).to have_css('h1 svg.s32')
    end

    it 'keeps a Cancel link next to Authenticate' do
      expect(page).to have_link('Cancel', href: '/projects/new')
    end

    it 'keeps the ci_cd_only field and repo-only scope text' do
      expect(page).to have_field('ci_cd_only', type: :hidden, with: 'true')
      expect(page).to have_content('Use a classic token with the repo scope.')
      expect(page).not_to have_content('read:org')
    end
  end
end
