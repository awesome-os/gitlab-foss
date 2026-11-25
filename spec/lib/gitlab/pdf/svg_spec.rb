# frozen_string_literal: true

require 'fast_spec_helper'

RSpec.describe Gitlab::PDF::SVG, feature_category: :vulnerability_management do
  describe '.draw' do
    let(:pdf) { Prawn::Document.new }
    let(:remote_image_svg) do
      '<svg xmlns="http://www.w3.org/2000/svg" width="10" height="10">' \
        '<image href="http://example.com/a.svg" width="10" height="10"/><rect width="5" height="5"/></svg>'
    end

    before do
      allow(pdf).to receive(:svg).and_call_original
    end

    it 'sanitizes the SVG and disables remote and file requests' do
      described_class.draw(pdf, remote_image_svg, width: 10)

      expect(pdf).to have_received(:svg).with(
        Gitlab::PDF::SvgSanitizer.sanitize(remote_image_svg),
        { width: 10, enable_web_requests: false, enable_file_requests_with_root: nil }
      )
    end

    it 'does not let options enable remote requests' do
      described_class.draw(pdf, remote_image_svg, enable_web_requests: true)

      expect(pdf).to have_received(:svg).with(anything, hash_including(enable_web_requests: false))
    end

    context 'when the SVG is trusted' do
      it 'does not sanitize it and still does not fetch remote images' do
        expect(Net::HTTP).not_to receive(:get)

        described_class.draw(pdf, remote_image_svg, trusted: true)

        expect(pdf).to have_received(:svg).with(remote_image_svg, hash_including(enable_web_requests: false))
      end
    end

    context 'when the SVG is rejected by the sanitizer' do
      it 'does not render anything' do
        expect(described_class.draw(pdf, '<use href="#a"/>')).to be_nil
        expect(pdf).not_to have_received(:svg)
      end
    end
  end
end
