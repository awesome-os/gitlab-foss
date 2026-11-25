# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'layouts/oauth_error', feature_category: :system_access do
  let(:error_css) { '.error-page { color: red; }' }

  before do
    allow(view).to receive_messages(vite_enabled?: false, error_css: error_css)
  end

  it 'inlines the asset pipeline error stylesheet' do
    allow(view).to receive(:rspack_stylesheets?).and_return(false)

    render

    expect(rendered).to include(error_css)
    expect(rendered).not_to have_css('link[rel="stylesheet"]', visible: :all)
  end

  context 'when Rspack serves the stylesheets' do
    before do
      allow(view).to receive(:rspack_stylesheets?).and_return(true)
      allow(Gitlab::Webpack::Manifest).to receive(:entrypoint_paths)
        .with('styles/errors', manifest_filename: anything)
        .and_return(%w[/assets/webpack/styles/errors.css])
    end

    it 'links the Rspack error stylesheet' do
      render

      expect(rendered).to have_css('link[href="/assets/webpack/styles/errors.css"]', visible: :all)
      expect(rendered).not_to include(error_css)
    end
  end
end
