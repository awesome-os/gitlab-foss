# frozen_string_literal: true

require 'fast_spec_helper'

# CE builds don't compile ee/app/assets/stylesheets, and the Rspack manifest
# raises on a missing entry, so a CE view must not ask for an EE-only stylesheet.
RSpec.describe 'page-specific styles requested from CE code', feature_category: :tooling do
  root = File.expand_path('../..', __dir__)
  stylesheets = File.join(root, 'app/assets/stylesheets')

  requested = Dir.glob(File.join(root, 'app/**/*.{haml,rb,erb}')).flat_map do |file|
    File.read(file).scan(/add_page_specific_style[ (]+['"]([^'"]+)['"]/).flatten.map do |path|
      [path, file.delete_prefix("#{root}/")]
    end
  end

  it 'finds the calls' do
    expect(requested).not_to be_empty
  end

  requested.each do |path, file|
    it "#{path} (#{file}) has a CE source" do
      sources = Dir.glob(File.join(stylesheets, "#{path}.{scss,css}"))

      expect(sources).not_to be_empty,
        "#{file} requests '#{path}', which has no file in app/assets/stylesheets. " \
          "Move the stylesheet out of ee/ or the call into an EE view."
    end
  end
end
