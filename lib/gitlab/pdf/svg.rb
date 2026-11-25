# frozen_string_literal: true

require "prawn-svg"

module Gitlab
  module PDF
    # Every SVG rendered into a PDF must go through this module instead of calling `pdf.svg`.
    # prawn-svg fetches remote URLs by default, and is not safe for untrusted markup.
    module SVG
      # @param pdf [Prawn::Document]
      # @param svg [String] the SVG markup
      # @param trusted [Boolean] true only for SVG built by GitLab from typed values
      # @param options [Hash] options passed to prawn-svg, for example `width:` or `at:`
      # @return [Hash, nil] the prawn-svg result, or nil when the SVG was rejected
      def self.draw(pdf, svg, trusted: false, **options)
        svg = SvgSanitizer.sanitize(svg) unless trusted
        return if svg.blank?

        pdf.svg(svg, **options, enable_web_requests: false, enable_file_requests_with_root: nil)
      end
    end
  end
end
