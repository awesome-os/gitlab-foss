# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Banzai::Filter::BaseRelativeLinkFilter do
  let(:filter_class) do
    Class.new(described_class) do
      def call
        result[:relative_url_root] = relative_url_root
        result[:links] = linkable_attributes.map(&:value)

        doc
      end
    end
  end

  def run(html)
    result = {}
    filter_class.call(html, {}, result)

    result
  end

  describe '#relative_url_root' do
    it 'is the configured path prefix' do
      Banzai.configure { |config| config.relative_url_root = '/gitlab' }

      expect(run('')[:relative_url_root]).to eq('/gitlab')
    end

    it 'is `/` when the prefix is blank' do
      Banzai.configure { |config| config.relative_url_root = '' }

      expect(run('')[:relative_url_root]).to eq('/')
    end
  end

  describe '#linkable_attributes' do
    it 'collects link and media sources, skipping `.gfm` and protocol-relative ones' do
      html = <<~HTML
        <a href="/docs">docs</a>
        <a class="gfm" href="/issues/1">#1</a>
        <img src="/uploads/a.png">
        <video data-src="/uploads/b.mp4"></video>
        <audio src="//cdn.example.com/c.mp3"></audio>
      HTML

      expect(run(html)[:links]).to contain_exactly('/docs', '/uploads/a.png', '/uploads/b.mp4')
    end
  end
end
