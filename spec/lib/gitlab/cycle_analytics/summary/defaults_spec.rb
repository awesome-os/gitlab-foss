# frozen_string_literal: true

require 'fast_spec_helper'

RSpec.describe Gitlab::CycleAnalytics::Summary::Defaults, feature_category: :value_stream_management do
  subject(:summary) do
    defaults = described_class
    stub_const('TestSummary', Class.new { include defaults }).new
  end

  it 'raises NotImplementedError from #title' do
    expect { summary.title }.to raise_error(NotImplementedError, 'Expected TestSummary to implement title')
  end

  it 'raises NotImplementedError from #value' do
    expect { summary.value }.to raise_error(NotImplementedError, 'Expected TestSummary to implement value')
  end
end
