# frozen_string_literal: true

module Mcp
  module Tools
    module Concerns
      # Returns text in line windows of at most MAX_WINDOW_BYTES, with a system_instruction
      # that tells the caller how to fetch the next window.
      module LineWindow
        DEFAULT_LIMIT = 500
        MAX_LIMIT = 2000
        MAX_WINDOW_BYTES = 32.kilobytes

        private

        def line_window(text, offset:, limit:, line_byte_offset:)
          text = text.to_s
          lines = text.lines
          offset = [offset.to_i, 0].max
          limit ||= DEFAULT_LIMIT
          line_byte_offset = line_byte_offset.to_i
          window = lines[offset, limit] || []

          if line_byte_offset > 0 && window.any?
            validate_line_byte_offset!(window.first, offset, line_byte_offset)
            window[0] = window.first.byteslice(line_byte_offset..)
          end

          requested_lines = window.size
          window, cut_bytes = cap_window_bytes(window)
          next_offset = offset + window.size

          system_instruction =
            if cut_bytes
              cut_line_system_instruction(offset, line_byte_offset + cut_bytes)
            elsif window.empty? && lines.any?
              past_end_system_instruction(offset, lines.size)
            elsif next_offset < lines.size
              next_window_system_instruction(
                next_offset, limit,
                remaining_lines: lines.size - next_offset,
                resumed_mid_line: line_byte_offset > 0,
                shortened: window.size < requested_lines
              )
            end

          {
            content: window.join,
            metadata: {
              total_lines: lines.size,
              returned_lines: window.empty? ? nil : { start: offset + 1, end: next_offset },
              truncated: window.size < lines.size || cut_bytes.present?,
              size_bytes: text.bytesize
            },
            system_instruction: system_instruction
          }.compact
        end

        def validate_line_byte_offset!(line, offset, line_byte_offset)
          if line_byte_offset >= line.bytesize
            raise ArgumentError,
              "line_byte_offset #{line_byte_offset} is past the end of line #{offset + 1}, " \
                "which is #{line.bytesize} bytes. Use the line_byte_offset that system_instruction gives."
          end

          return if line.byteslice(line_byte_offset..).valid_encoding?

          raise ArgumentError,
            "line_byte_offset #{line_byte_offset} is inside a multi-byte character on line #{offset + 1}. " \
              "Use the line_byte_offset that system_instruction gives."
        end

        def cap_window_bytes(window)
          first = window.first

          if first && first.bytesize > MAX_WINDOW_BYTES
            head = first.byteslice(0, MAX_WINDOW_BYTES).scrub('')

            return [[head], head.bytesize]
          end

          bytes = 0
          [window.take_while { |line| (bytes += line.bytesize) <= MAX_WINDOW_BYTES }, nil]
        end

        def cut_line_system_instruction(offset, next_line_byte_offset)
          "Line #{offset + 1} is longer than the #{MAX_WINDOW_BYTES} byte response limit and was cut. " \
            "To read the rest of the line, call again with " \
            "{\"offset\": #{offset}, \"line_byte_offset\": #{next_line_byte_offset}}."
        end

        def past_end_system_instruction(offset, total_lines)
          "Offset #{offset} is past the end of the content (#{total_lines} lines). " \
            "Call again with an offset below #{total_lines}."
        end

        # After a call that resumed mid-line, the next call must reset line_byte_offset to start on a new line.
        def next_window_system_instruction(next_offset, limit, remaining_lines:, resumed_mid_line:, shortened:)
          line_byte_offset_reset = resumed_mid_line ? ', "line_byte_offset": 0' : ''
          instruction = "Content truncated. Remaining lines: #{remaining_lines}. To view more, call again with " \
            "{\"offset\": #{next_offset}, \"limit\": #{limit}#{line_byte_offset_reset}}."

          return instruction unless shortened

          "#{instruction} The window was shortened to stay within the #{MAX_WINDOW_BYTES} byte response limit."
        end
      end
    end
  end
end
