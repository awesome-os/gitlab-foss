# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'shared/notes/_hints.html.haml', feature_category: :text_editors do
  it 'renders the upload error message as one sentence with buttons', :aggregate_failures do
    render partial: 'shared/notes/hints'

    expect(rendered).to have_css('.uploading-error-container', text: 'Try again or attach a new file.', visible: :all)
    expect(rendered).to have_button('Try again', class: 'retry-uploading-link', visible: :all)
    expect(rendered).to have_button('attach a new file', class: 'attach-new-file', visible: :all)
  end
end
