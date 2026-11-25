# frozen_string_literal: true

require 'spec_helper'

RSpec.describe EnableSearchSettingsHelper do
  describe '#enable_search_settings' do
    def search_settings
      helper.content_for(:search_settings)
    end

    it 'sets content for search_settings' do
      expect(search_settings).to be_nil

      locals = { container_class: 'test-container-class' }

      helper.enable_search_settings(locals: locals)

      expect(search_settings).to eql(helper.render("shared/search_settings", locals))
    end
  end
end
