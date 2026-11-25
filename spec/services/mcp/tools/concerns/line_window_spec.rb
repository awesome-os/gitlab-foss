# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mcp::Tools::Concerns::LineWindow, feature_category: :mcp_server do
  let(:reader) { Class.new { include Mcp::Tools::Concerns::LineWindow }.new }
  let(:text) { "one\ntwo\nthree\n" }
  let(:arguments) { {} }

  def read(overrides = {})
    reader.send(:line_window, text, **{ offset: nil, limit: nil, line_byte_offset: nil }.merge(arguments, overrides))
  end

  # Follows each system_instruction until the reader stops giving one.
  def read_all
    overrides = {}
    rebuilt = +''

    loop do
      window = read(overrides)
      rebuilt << window[:content]
      break unless window[:system_instruction]

      overrides = Gitlab::Json::SafeParser.parse(window[:system_instruction][/\{.*\}/]).symbolize_keys
    end

    rebuilt
  end

  it 'returns the whole text when it fits in one window' do
    expect(read).to eq(
      content: text,
      metadata: { total_lines: 3, returned_lines: { start: 1, end: 3 }, truncated: false, size_bytes: 14 }
    )
  end

  context 'when the text is empty' do
    let(:text) { nil }

    it 'returns an empty window without a system_instruction' do
      expect(read).to eq(
        content: '',
        metadata: { total_lines: 0, returned_lines: nil, truncated: false, size_bytes: 0 }
      )
    end
  end

  context 'when limit is lower than the number of lines' do
    let(:arguments) { { limit: 1 } }

    it 'returns the window and the next offset', :aggregate_failures do
      window = read(offset: 1)

      expect(window[:content]).to eq("two\n")
      expect(window[:metadata]).to include(returned_lines: { start: 2, end: 2 }, truncated: true)
      expect(window[:system_instruction]).to eq(
        'Content truncated. Remaining lines: 1. To view more, call again with {"offset": 2, "limit": 1}.'
      )
    end

    it 'rebuilds the text when the caller follows each system_instruction' do
      expect(read_all).to eq(text)
    end
  end

  context 'when offset is past the end' do
    it 'returns no content and says so', :aggregate_failures do
      window = read(offset: 3)

      expect(window[:content]).to eq('')
      expect(window[:system_instruction]).to eq(
        'Offset 3 is past the end of the content (3 lines). Call again with an offset below 3.'
      )
    end
  end

  context 'when the window is larger than the byte limit' do
    before do
      stub_const("#{described_class}::MAX_WINDOW_BYTES", 8)
    end

    it 'drops whole lines to stay within the limit', :aggregate_failures do
      window = read

      expect(window[:content]).to eq("one\ntwo\n")
      expect(window[:system_instruction]).to eq(
        'Content truncated. Remaining lines: 1. To view more, call again with {"offset": 2, "limit": 500}. ' \
          'The window was shortened to stay within the 8 byte response limit.'
      )
    end

    context 'when a single line is longer than the limit' do
      let(:text) { "#{'a' * 20}\nshort\n" }

      it 'cuts the line and gives the byte to continue from', :aggregate_failures do
        window = read

        expect(window[:content]).to eq('a' * 8)
        expect(window[:system_instruction]).to eq(
          'Line 1 is longer than the 8 byte response limit and was cut. ' \
            'To read the rest of the line, call again with {"offset": 0, "line_byte_offset": 8}.'
        )
      end

      it 'rebuilds the text when the caller follows each system_instruction' do
        expect(read_all).to eq(text)
      end

      it 'rejects a line_byte_offset past the end of the line' do
        expect { read(line_byte_offset: 21) }.to raise_error(
          ArgumentError, /line_byte_offset 21 is past the end of line 1, which is 21 bytes/
        )
      end
    end

    context 'when the cut would split a multi-byte character' do
      let(:text) { "#{'é' * 10}\n" }

      it 'rejects a line_byte_offset inside the character' do
        expect { read(line_byte_offset: 1) }.to raise_error(
          ArgumentError, /line_byte_offset 1 is inside a multi-byte character on line 1/
        )
      end

      it 'rebuilds the text when the caller follows each system_instruction' do
        expect(read_all).to eq(text)
      end
    end
  end
end
