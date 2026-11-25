# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Iframe embeds (JavaScript fixtures)', feature_category: :markdown do
  include JavaScriptFixturesHelpers

  let_it_be(:project) { create(:project) }

  let(:cases) do
    urls.flat_map do |url, embeds|
      { 'image' => "![](#{url})", 'iframe' => iframe_markdown(url) }.map do |form, markdown|
        { input: url, form: form, embeds: embeds, html: Banzai.render(markdown, project: project) }
      end
    end
  end

  let(:providers) { Banzai::IframeProviders.frontend_config }
  let(:response) { Gitlab::Json.generate(providers: providers, cases: cases) }

  let(:urls) do
    {
      'https://www.youtube.com/watch?v=dQw4w9WgXcQ&t=30' => true,
      'https://youtu.be/dQw4w9WgXcQ' => true,
      'https://www.youtube.com/embed/dQw4w9WgXcQ?start=30' => true,
      'https://WWW.YouTube.com/embed/dQw4w9WgXcQ' => true,
      'https://www.youtube.com:443/embed/dQw4w9WgXcQ' => true,
      'https://www.youtube.com/watch?v=abc%26autoplay%3D1' => true,
      'https://www.youtube.com/embed/dQw4w9WgXcQ\@example.com' => true,
      'https://ｗｗｗ.youtube.com/embed/dQw4w9WgXcQ' => true,
      'https://www.figma.com/design/abc123/Title?node-id=1-2' => true,
      'https://embed.figma.com/proto/abc123?embed-host=gitlab' => true,
      'https://example.com\@www.youtube.com/embed/dQw4w9WgXcQ' => false,
      'https://example.com:\@www.youtube.com/embed/dQw4w9WgXcQ' => false,
      'https://example.com%5C@www.youtube.com/embed/dQw4w9WgXcQ' => false,
      'https://user:password@www.youtube.com/embed/dQw4w9WgXcQ' => false,
      'https://@www.youtube.com/embed/dQw4w9WgXcQ' => false,
      'https://www.youtube.com:8443/embed/dQw4w9WgXcQ' => false,
      'https://www.youtube.com:0/embed/dQw4w9WgXcQ' => false,
      'https://www.youtube.com:000/embed/dQw4w9WgXcQ' => false,
      'https://www.youtube.com./embed/dQw4w9WgXcQ' => false,
      'https://www.youtube.com%2e/embed/dQw4w9WgXcQ' => false,
      'https://www.youtube.com．/embed/dQw4w9WgXcQ' => false,
      'https://www.youtube.com。/embed/dQw4w9WgXcQ' => false,
      'https://www.youtube.com\embed/dQw4w9WgXcQ' => false,
      "https://www.you\ttube.com/embed/dQw4w9WgXcQ" => false,
      'https:www.youtube.com/embed/dQw4w9WgXcQ' => false,
      'https:/www.youtube.com/embed/dQw4w9WgXcQ' => false,
      'https:///www.youtube.com/embed/dQw4w9WgXcQ' => false,
      'https://example.com?@www.youtube.com/embed/dQw4w9WgXcQ' => false,
      'https://example.com#@www.youtube.com/embed/dQw4w9WgXcQ' => false,
      'https://www.youtube.com.evil.example/embed/dQw4w9WgXcQ' => false,
      'http://www.youtube.com/embed/dQw4w9WgXcQ' => false
    }
  end

  before do
    stub_application_setting(iframe_rendering_enabled: true, iframe_rendering_allowlist: %w[youtube figma])
  end

  def iframe_markdown(url)
    fragment = Nokogiri::HTML5.fragment('')
    fragment.add_child(fragment.document.create_element('iframe', src: url))
    fragment.to_html
  end

  def embedded?(html)
    Nokogiri::HTML5.fragment(html).at_css('.js-render-iframe').present?
  end

  it 'iframe_embeds/cases.json', :aggregate_failures do
    expect(providers.keys).to eq(%w[youtube figma])
    expect(cases.to_h { |c| [[c[:form], c[:input]], embedded?(c[:html])] })
      .to eq(cases.to_h { |c| [[c[:form], c[:input]], c[:embeds]] })
  end
end
