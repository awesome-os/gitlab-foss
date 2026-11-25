# frozen_string_literal: true

require 'fast_spec_helper'

RSpec.describe 'MCP GraphQL tools read the root field through operation_data', feature_category: :mcp_server do
  it 'has no tool reading operation_name directly' do
    files = Dir.glob('{,ee/}app/services/mcp/tools/**/*.rb', base: Rails.root).reject { |f| f.include?('/base/') }
    offenders = files.flat_map do |file|
      Rails.root.join(file).readlines.each_with_index.filter_map do |line, i|
        next if line.strip.start_with?('#') || line.match?(/def operation_name\b/)

        "#{file}:#{i + 1}" if line.match?(/(?<![:\w])operation_name\b(?!:)/)
      end
    end

    expect(offenders).to be_empty,
      "Read the response payload with operation_data(result), not operation_name: #{offenders}"
  end
end
