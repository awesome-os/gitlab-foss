# frozen_string_literal: true

require 'spec_helper'

require_relative '../../../tooling/docs/event_handling'

RSpec.describe Docs::EventHandling, feature_category: :tooling do
  subject(:render) { described_class.new.render }

  before do
    allow(Docs::EventDocPaths).to receive(:doc_files).with(Rails.root).and_return(
      %w[
        /root/data/events/templates/example.yml
        /root/domains/cd/data/events/cd/b_event.yml
        /root/data/events/ci/a_event.yml
      ]
    )
  end

  it 'groups top-level and domain docs by domain, skipping templates' do
    allow(YAML).to receive(:safe_load_file) { |file| { 'event' => File.basename(file, '.yml') } }

    allow_next_instance_of(ERB) do |template|
      expect(template).to receive(:result_with_hash) do |entries:, domains:|
        expect(domains).to eq(%w[cd ci])
        expect(entries.map { |e| e.values_at('domain', 'event') }).to eq([%w[cd b_event], %w[ci a_event]])
      end
    end

    render
  end

  it 'names the file that fails to parse' do
    allow(YAML).to receive(:safe_load_file).and_raise(Psych::SyntaxError.new('f', 1, 1, 0, 'bad', 'ctx'))

    expect { render }.to raise_error(%r{Failed to parse /root/domains/cd/data/events/cd/b_event\.yml})
  end
end
