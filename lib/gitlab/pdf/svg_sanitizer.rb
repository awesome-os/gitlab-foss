# frozen_string_literal: true

require 'loofah'

module Gitlab
  module PDF
    # Reduces an untrusted SVG (for example a chart exported by the frontend) to an allowlist of
    # plain drawing elements and attributes before prawn-svg parses it.
    class SvgSanitizer
      MAX_BYTES = 5.megabytes

      ALLOWED_ELEMENTS = %w[
        svg g defs path rect circle ellipse line polyline polygon text tspan
        clipPath linearGradient radialGradient stop
      ].to_set.freeze

      ALLOWED_ATTRIBUTES = %w[
        id class style transform transform-origin opacity visibility display pointer-events
        fill fill-opacity fill-rule stroke stroke-width stroke-opacity stroke-dasharray
        stroke-dashoffset stroke-linecap stroke-linejoin stroke-miterlimit paint-order clip-path clip-rule
        x y x1 y1 x2 y2 cx cy r rx ry fx fy dx dy width height d points viewBox preserveAspectRatio
        version baseProfile offset stop-color stop-opacity gradientUnits gradientTransform spreadMethod
        clipPathUnits dominant-baseline text-anchor font-family font-size font-weight font-style
        letter-spacing xml:space
      ].to_set.freeze

      # The only reference allowed is a local id, e.g. ECharts' `clip-path="url(#zr0-c0)"`.
      SAFE_URL_REFERENCE = /url\(#[\w-]{1,64}\)/
      UNSAFE_ATTRIBUTE_VALUE = /url|\\/i

      # @param svg [String, nil] the SVG markup
      # @return [String, nil] the sanitized SVG, or nil when it is too large or has no `svg` root
      def self.sanitize(svg)
        return if svg.blank? || svg.bytesize > MAX_BYTES

        document = Loofah.xml_document(svg)
        return unless document.root&.name == 'svg'

        document.scrub!(Scrubber.new)
        document.root.to_xml(save_with: Nokogiri::XML::Node::SaveOptions::AS_XML)
      end

      class Scrubber < Loofah::Scrubber
        def initialize
          super
          @direction = :top_down
        end

        def scrub(node)
          return CONTINUE if node.text?

          unless node.element? && ALLOWED_ELEMENTS.include?(node.name)
            node.unlink
            return STOP
          end

          node.attribute_nodes.each do |attr|
            attr.unlink unless allowed_attribute?(attr)
          end

          CONTINUE
        end

        private

        def allowed_attribute?(attr)
          name = attr.namespace ? "#{attr.namespace.prefix}:#{attr.name}" : attr.name

          ALLOWED_ATTRIBUTES.include?(name) &&
            !attr.value.gsub(SAFE_URL_REFERENCE, '').match?(UNSAFE_ATTRIBUTE_VALUE)
        end
      end
    end
  end
end
