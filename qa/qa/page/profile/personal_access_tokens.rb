# frozen_string_literal: true

require 'date'

module QA
  module Page
    module Profile
      class PersonalAccessTokens < Page::Base
        include Page::Component::AccessTokens

        view 'app/assets/javascripts/personal_access_tokens/components/created_personal_access_token.vue' do
          element 'created-access-token-field'
        end

        view 'app/assets/javascripts/personal_access_tokens/components/create_personal_access_token_dropdown.vue' do
          element 'create-token-dropdown'
          element 'create-legacy-token-item'
        end

        def go_to_new_token_form
          page.visit "#{Runtime::Scenario.gitlab_address}/-/user_settings/personal_access_tokens"
          click_button('Generate token')
          click_element('create-legacy-token-item')
        end
      end
    end
  end
end
