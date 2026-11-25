# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Banzai::Filter::References::ReferenceFilter, feature_category: :markdown do
  let(:project) { build_stubbed(:project) }

  describe '#each_node' do
    it 'iterates over the nodes in a document' do
      document = Nokogiri::HTML.fragment('<a href="foo">foo</a>')
      filter = described_class.new(document, project: project)

      expect { |b| filter.each_node(&b) }
        .to yield_with_args(an_instance_of(Nokogiri::XML::Element))
    end

    it 'returns an Enumerator when no block is given' do
      document = Nokogiri::HTML.fragment('<a href="foo">foo</a>')
      filter = described_class.new(document, project: project)

      expect(filter.each_node).to be_an_instance_of(Enumerator)
    end

    it 'skips links with a "gfm" class' do
      document = Nokogiri::HTML.fragment('<a href="foo" class="gfm">foo</a>')
      filter = described_class.new(document, project: project)

      expect { |b| filter.each_node(&b) }.not_to yield_control
    end

    it 'skips text nodes in pre elements' do
      document = Nokogiri::HTML.fragment('<pre>foo</pre>')
      filter = described_class.new(document, project: project)

      expect { |b| filter.each_node(&b) }.not_to yield_control
    end

    it 'skips text nodes in inline diff elements' do
      document = Nokogiri::HTML.fragment('<span class="idiff">foo</span>')
      filter = described_class.new(document, project: project)

      expect { |b| filter.each_node(&b) }.not_to yield_control
    end
  end

  describe '#nodes' do
    it 'returns an Array of the HTML nodes' do
      document = Nokogiri::HTML.fragment('<a href="foo">foo</a>')
      filter = described_class.new(document, project: project)

      expect(filter.nodes).to eq([document.children[0]])
    end
  end

  RSpec.shared_context 'document nodes' do
    let(:document) { Nokogiri::HTML.fragment('<p data-sourcepos="1:1-1:18"></p>') }
    let(:nodes) { [] }
    let(:filter) { described_class.new(document, project: project) }
    let(:ref_pattern) { nil }
    let(:href_link) { nil }

    before do
      nodes.each do |node|
        document.children.first.add_child(node)
      end
    end
  end

  RSpec.shared_context 'recorded replacements' do
    let(:document) { Nokogiri::HTML.fragment('<p>one</p><p>two</p><p>three</p>') }
    let(:link) { %(<a href="reference_url" class="gfm gfm-user">Reference</a>) }
    # Index 1 is left untouched to check that unaffected nodes keep their position.
    let(:replacements) do
      {
        0 => "1.1 #{link} 1.2 #{link}",
        2 => "3.1 #{link}"
      }
    end

    # The new `gfm` links are excluded from the shared node list by `query`.
    let(:expected_texts) { ['1.1 ', ' 1.2 ', 'two', '3.1 '] }
  end

  RSpec.shared_examples 'replaces text' do |method_name, index|
    let(:args) { [filter.nodes[index], index, ref_pattern || href_link].compact }

    def call_method(method_name, replacement)
      filter.send(method_name, *args) { replacement }
    end

    context 'when content didnt change' do
      it 'does not replace link node with html' do
        call_method(method_name, existing_content)

        expect(filter).not_to receive(:replace_node_with_html)
      end
    end

    context 'when link node has changed' do
      let(:html) { %(text <a href="reference_url" class="gfm gfm-user" title="reference">Reference</a>) }

      it 'calls replace_node_with_html' do
        expect(filter).to receive(:replace_node_with_html).with(filter.nodes[index], index, html)

        call_method(method_name, html)
      end

      it 'records the replacement without touching the document' do
        call_method(method_name, html)

        expect(filter.instance_variable_get(:@replacements)).to eq({ index => html })
        expect(document.css('a')).to be_empty
      end

      it 'replaces the node when the recorded replacements are applied' do
        call_method(method_name, html)
        filter.send(:update_nodes!)

        expect(document.css('a').length).to eq 1
        expect(filter.nodes[index]).to eq(filter.each_node.to_a[index])
      end
    end
  end

  RSpec.shared_examples 'replaces document node' do |method_name|
    context 'when parent has only one node' do
      let(:nodes) { [node] }

      it_behaves_like 'replaces text', method_name, 0
    end

    context 'when parent has multiple nodes' do
      let(:node1) { Nokogiri::HTML.fragment('<span>span text</span>') }
      let(:node2) { Nokogiri::HTML.fragment('<span>text</span>') }

      context 'when pattern matches in the first node' do
        let(:nodes) { [node, node1, node2] }

        it_behaves_like 'replaces text', method_name, 0
      end

      context 'when pattern matches in the middle node' do
        let(:nodes) { [node1, node, node2] }

        it_behaves_like 'replaces text', method_name, 1
      end

      context 'when pattern matches in the last node' do
        let(:nodes) { [node1, node2, node] }

        it_behaves_like 'replaces text', method_name, 2
      end
    end
  end

  describe '#replace_node_when_text_matches' do
    include_context 'document nodes'
    let(:node) { Nokogiri::HTML.fragment('text @reference') }

    let(:ref_pattern) { %r{(?<!\w)@(?<user>[a-zA-Z0-9_\-.]*)}x }

    context 'when node has no reference pattern' do
      let(:node) { Nokogiri::HTML.fragment('random text') }
      let(:nodes) { [node] }

      it 'skips node' do
        expect { |b| filter.send(:replace_node_when_text_matches, filter.nodes[0], 0, ref_pattern, &b) }.not_to yield_control
      end
    end

    it_behaves_like 'replaces document node', :replace_node_when_text_matches do
      let(:existing_content) { node.to_html }
    end
  end

  describe '#call_and_update_nodes' do
    include_context 'recorded replacements'
    let(:filter) { described_class.new(document, project: project) }

    it 'applies the recorded replacements after call and updates the shared nodes', :aggregate_failures do
      expect(filter).to receive(:call) do
        filter.nodes
        filter.instance_variable_set(:@replacements, replacements)
      end
      expect(filter).to receive(:with_update_nodes).and_call_original
      expect(filter).to receive(:update_nodes!).and_call_original

      filter.call_and_update_nodes

      expect(document.css('a').length).to eq 3
      expect(filter.result[:reference_filter_nodes].map(&:text)).to eq(expected_texts)
      expect(filter.result[:reference_filter_nodes]).to all(have_attributes(parent: be_present))
    end
  end

  describe '.call' do
    include_context 'recorded replacements'

    let(:result) { { reference_filter_nodes: document.xpath('.//text()').to_a } }

    it 'applies the recorded replacements and updates the shared nodes', :aggregate_failures do
      expect_next_instance_of(described_class) do |filter|
        expect(filter).to receive(:call_and_update_nodes).and_call_original
        expect(filter).to receive(:with_update_nodes).and_call_original
        expect(filter).to receive(:call) { filter.instance_variable_set(:@replacements, replacements) }
        expect(filter).to receive(:update_nodes!).and_call_original
        expect(filter).to receive(:nodes?).and_call_original
      end

      described_class.call(document, { project: project }, result)

      expect(document.css('a').length).to eq 3
      expect(result[:reference_filter_nodes].map(&:text)).to eq(expected_texts)
    end
  end

  describe '#replace_references_in_text_with_html' do
    let(:document) { Nokogiri::HTML.fragment('<a href="foo">foo</a>') }
    let(:filter) { described_class.new(document, project:) }

    context 'enumerator yields non-MatchData' do
      let(:weird_enumerator) { ["weh"].each }

      it 'raises ArgumentError' do
        expect { filter.replace_references_in_text_with_html(weird_enumerator) }.to raise_error(ArgumentError)
      end
    end
  end

  describe '#nodes?' do
    let_it_be(:document) { Nokogiri::HTML.fragment('<a href="foo">foo</a>') }
    let(:filter) { described_class.new(document, project: project) }

    it 'returns false when nodes are not loaded' do
      expect(filter.nodes?).to be_falsey
    end

    it 'returns true when nodes are loaded' do
      filter.nodes

      expect(filter.nodes?).to be_truthy
    end
  end

  context 'abstract methods' do
    let(:document) { Nokogiri::HTML.fragment('<a href="foo">foo</a>') }
    let(:filter) { described_class.new(document, project: project) }

    describe '#references_in' do
      it 'raises NotImplementedError' do
        expect { filter.references_in('foo', %r{(?<!\w)}) }.to raise_error(NotImplementedError)
      end
    end

    describe '#object_link_filter' do
      it 'raises NotImplementedError' do
        expect { filter.send(:object_link_filter, 'foo', %r{(?<!\w)}) }.to raise_error(NotImplementedError)
      end
    end
  end

  it_behaves_like 'pipeline timing check', context: { project: nil }
end
