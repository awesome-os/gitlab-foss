# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'User Settings > Personal access tokens', :with_current_organization, :js, feature_category: :system_access do
  let(:user) { create(:user) }

  before do
    sign_in(user)
  end

  describe "feed token" do
    def feed_token_description
      "Your feed token authenticates you when your RSS reader loads a personalized RSS feed or when your calendar\
 application loads a personalized calendar. It is visible in those feed URLs. It cannot be used to access\
 any other data."
    end

    context "when enabled" do
      it "displays feed token" do
        allow(Gitlab::CurrentSettings).to receive(:disable_feed_token).and_return(false)
        visit user_settings_personal_access_tokens_path

        within_testid('feed-token-container') do
          click_button('Click to reveal')

          expect(page).to have_field('Feed token', with: user.feed_token)
          expect(page).to have_content(feed_token_description)
        end
      end
    end

    context "when disabled" do
      it "does not display feed token" do
        allow(Gitlab::CurrentSettings).to receive(:disable_feed_token).and_return(true)
        visit user_settings_personal_access_tokens_path

        expect(page).not_to have_content(feed_token_description)
        expect(page).not_to have_field('Feed token')
      end
    end
  end
end
