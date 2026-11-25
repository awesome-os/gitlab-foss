# frozen_string_literal: true

require 'fast_spec_helper'

RSpec.describe Gitlab::PDF::SvgSanitizer, feature_category: :vulnerability_management do
  describe '.sanitize' do
    subject(:sanitized) { described_class.sanitize(svg) }

    def wrap(content)
      %(<svg xmlns="http://www.w3.org/2000/svg" width="100" height="50">#{content}</svg>)
    end

    context 'with chart markup like ECharts exports' do
      let(:svg) do
        wrap(<<~SVG.squish)
          <rect width="100" height="50" x="0" y="0" fill="none"></rect>
          <g clip-path="url(#zr0-c0)">
            <path d="M0 0L10 10" fill="none" stroke="#5470c6" stroke-width="2" paint-order="fill"></path>
          </g>
          <text dominant-baseline="central" text-anchor="middle" style="font: 12px sans-serif" xml:space="preserve"
            transform="translate(10 20)" fill="#666666">Jan 1</text>
          <defs>
            <clipPath id="zr0-c0"><path d="M0 0l100 0l0 50l-100 0Z" fill="#000"></path></clipPath>
            <linearGradient id="zr0-g0" x1="0" y1="0" x2="0" y2="1">
              <stop offset="0%" stop-color="#fff" stop-opacity="1"></stop>
            </linearGradient>
          </defs>
        SVG
      end

      it 'keeps the markup unchanged' do
        expect(Nokogiri::XML(sanitized).to_xml).to eq(Nokogiri::XML(svg).to_xml)
      end
    end

    context 'with elements that are not plain drawing elements' do
      let(:svg) do
        wrap(<<~SVG.squish)
          <use href="#a"/>
          <style>rect { fill: red }</style>
          <image href="http://example.com/a.svg"/>
          <tref href="#a"/>
          <foreignObject><div>a</div></foreignObject>
          <script>alert(1)</script>
          <pattern id="p"><rect/></pattern>
          <g><use href="#nested"/><rect id="kept"/></g>
        SVG
      end

      it 'removes them with their children' do
        expect(Nokogiri::XML(sanitized).root.element_children.map(&:name)).to eq(%w[g])
        expect(sanitized).to include('<g><rect id="kept"/></g>')
        expect(sanitized).not_to include('href', 'alert', '<div', 'fill: red')
      end
    end

    context 'with an element in another namespace that has an unsafe local name' do
      let(:svg) { wrap('<x:use xmlns:x="http://example.com" x:href="#a"/>') }

      it 'removes it' do
        expect(sanitized).not_to include('use')
      end
    end

    context 'with attributes that are not allowed' do
      let(:svg) do
        wrap(<<~SVG.squish)
          <rect href="#a" onload="alert(1)" data-foo="bar" fill="red"
            xmlns:xlink="http://www.w3.org/1999/xlink" xlink:href="#a"/>
        SVG
      end

      it 'removes them' do
        rect = Nokogiri::XML(sanitized).root.element_children.first

        expect(rect.attribute_nodes.map(&:name)).to eq(%w[fill])
      end
    end

    context 'with url references' do
      where(:value, :kept) do
        [
          ['url(#zr0-c0)', true],
          ['url(#a) none', true],
          ['url(#a"b)', false],
          ['url("#a")', false],
          ["url('#a')", false],
          ['url(http://example.com/a.svg)', false],
          ['URL(#a)', false],
          ['u\\rl(#a)', false],
          ["url(##{'a' * 65})", false]
        ]
      end

      with_them do
        let(:svg) { wrap(%(<rect fill='#{value}' style='fill: #{value}'/>)) }

        it 'keeps only local id references' do
          rect = Nokogiri::XML(sanitized).root.element_children.first

          expect(rect.key?('fill')).to eq(kept)
          expect(rect.key?('style')).to eq(kept)
        end
      end
    end

    context 'with comments, CDATA, processing instructions and entities' do
      let(:svg) do
        <<~SVG
          <?xml version="1.0"?>
          <!DOCTYPE svg [<!ENTITY a "aaaaaaaaaa">]>
          <svg xmlns="http://www.w3.org/2000/svg"><!-- comment --><?pi data?><text>&a;<![CDATA[b]]>c</text></svg>
        SVG
      end

      it 'removes them' do
        expect(sanitized).to eq('<svg xmlns="http://www.w3.org/2000/svg"><text>c</text></svg>')
      end
    end

    context 'when the root element is not svg' do
      let(:svg) { '<use href="#a"/>' }

      it { is_expected.to be_nil }
    end

    context 'when the SVG is not valid XML' do
      let(:svg) { 'not xml' }

      it { is_expected.to be_nil }
    end

    context 'when the SVG is blank' do
      let(:svg) { nil }

      it { is_expected.to be_nil }
    end

    context 'when the SVG is larger than the limit' do
      let(:svg) { wrap('<rect/>') }

      before do
        stub_const("#{described_class}::MAX_BYTES", svg.bytesize - 1)
      end

      it { is_expected.to be_nil }
    end
  end
end
