# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mcp::Tools::Concerns::SuggestionIdUnwrapping, feature_category: :mcp_server do
  let(:test_class) do
    Class.new do
      include Mcp::Tools::Concerns::SuggestionIdUnwrapping

      def unwrap(merge_request)
        unwrap_suggestion_ids(merge_request)
      end
    end
  end

  let(:gid) { 'gid://gitlab/Suggestion/42' }

  subject(:unwrapped) { test_class.new.unwrap(merge_request) }

  context 'with suggestions on notes and discussion notes' do
    let(:merge_request) do
      {
        'notes' => { 'nodes' => [{ 'suggestions' => { 'nodes' => [{ 'id' => gid }] } }] },
        'discussions' => {
          'nodes' => [{ 'notes' => { 'nodes' => [{ 'suggestions' => { 'nodes' => [{ 'id' => gid }] } }] } }]
        }
      }
    end

    it 'replaces each global ID with the integer id', :aggregate_failures do
      expect(unwrapped.dig('notes', 'nodes', 0, 'suggestions', 'nodes', 0, 'id')).to eq(42)
      expect(unwrapped.dig('discussions', 'nodes', 0, 'notes', 'nodes', 0, 'suggestions', 'nodes', 0, 'id'))
        .to eq(42)
    end
  end

  context 'when a suggestion node is null' do
    let(:merge_request) do
      { 'notes' => { 'nodes' => [{ 'suggestions' => { 'nodes' => [nil, { 'id' => gid }] } }] } }
    end

    it 'skips the null node and unwraps the rest' do
      expect(unwrapped.dig('notes', 'nodes', 0, 'suggestions', 'nodes')).to eq([nil, { 'id' => 42 }])
    end
  end

  context 'when a discussion node or a note node is null' do
    let(:merge_request) do
      {
        'notes' => { 'nodes' => [nil] },
        'discussions' => {
          'nodes' => [nil, { 'notes' => { 'nodes' => [nil, { 'suggestions' => { 'nodes' => [{ 'id' => gid }] } }] } }]
        }
      }
    end

    it 'skips the null nodes and unwraps the rest' do
      expect(unwrapped.dig('discussions', 'nodes', 1, 'notes', 'nodes', 1, 'suggestions', 'nodes', 0, 'id')).to eq(42)
    end
  end

  context 'when a suggestion ID is not a global ID' do
    let(:merge_request) do
      { 'notes' => { 'nodes' => [{ 'suggestions' => { 'nodes' => [{ 'id' => 'not-a-gid' }, { 'id' => gid }] } }] } }
    end

    it 'leaves that ID as it is and unwraps the rest' do
      expect(unwrapped.dig('notes', 'nodes', 0, 'suggestions', 'nodes'))
        .to eq([{ 'id' => 'not-a-gid' }, { 'id' => 42 }])
    end
  end

  context 'when notes, discussions and suggestions are not requested' do
    let(:merge_request) { { 'iid' => '1', 'notes' => { 'nodes' => [{ 'body' => 'hi' }] } } }

    it 'returns the merge request unchanged' do
      expect(unwrapped).to eq(merge_request)
    end
  end
end
