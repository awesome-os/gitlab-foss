# frozen_string_literal: true

require "spec_helper"

RSpec.describe Repositories::TreeFinder, feature_category: :source_code_management do
  include RepoHelpers
  using RSpec::Parameterized::TableSyntax

  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project, :repository, creator: user) }

  let(:repository) { project.repository }
  let(:tree_finder) { described_class.new(project, params) }
  let(:params) { {} }
  let(:first_page_ids) { tree_finder.execute.map(&:id) }

  describe "#execute" do
    subject { tree_finder.execute(gitaly_pagination: true) }

    it "returns an array" do
      is_expected.to be_an(Array)
    end

    it "includes 20 items by default" do
      expect(subject.size).to eq(20)
    end

    it "accepts a gitaly_pagination argument" do
      expect(repository).to receive(:tree).with(anything, anything, recursive: nil, rescue_not_found: nil, with_last_commit: false, pagination_params: { limit: 20, page_token: nil }).and_call_original
      expect(tree_finder.execute(gitaly_pagination: true)).to be_an(Array)

      expect(repository).to receive(:tree).with(anything, anything, recursive: nil, rescue_not_found: nil, with_last_commit: false).and_call_original
      expect(tree_finder.execute(gitaly_pagination: false)).to be_an(Array)
    end

    context "commit doesn't exist" do
      let(:params) do
        { ref: "nonesuchref" }
      end

      it "raises an error" do
        expect { subject }.to raise_error(described_class::CommitMissingError)
      end
    end

    describe "pagination_params" do
      let(:params) do
        { per_page: 5, page_token: nil }
      end

      it "has the per_page number of items" do
        expect(subject.size).to eq(5)
      end

      it "doesn't include any of the first page records" do
        first_page_ids = subject.map(&:id)
        second_page = described_class.new(project, { per_page: 5, page_token: first_page_ids.last }).execute(gitaly_pagination: true)

        expect(second_page.map(&:id)).not_to include(*first_page_ids)
      end
    end
  end

  describe '#next_cursor' do
    subject { tree_finder.next_cursor }

    it 'always nil before #execute call' do
      is_expected.to be_nil
    end

    context 'after #execute' do
      context 'with gitaly pagination' do
        before do
          tree_finder.execute(gitaly_pagination: true)
        end

        context 'without pagination params' do
          it { is_expected.to be_present }
        end

        context 'with pagination params' do
          let(:params) { { per_page: 5 } }

          it { is_expected.to be_present }

          context 'when all objects can be returned on the same page' do
            let(:params) { { per_page: 100 } }

            it { is_expected.to eq('') }
          end
        end
      end

      context 'without gitaly pagination' do
        before do
          tree_finder.execute(gitaly_pagination: false)
        end

        context 'without pagination params' do
          it { is_expected.to be_nil }
        end

        context 'with pagination params' do
          let(:params) { { per_page: 5 } }

          it { is_expected.to be_nil }

          context 'when all objects can be returned on the same page' do
            let(:params) { { per_page: 100 } }

            it { is_expected.to be_nil }
          end
        end
      end
    end
  end

  describe 'Gitaly offset for later pages', :use_clean_rails_memory_store_caching do
    let(:base_params) { { pagination: 'legacy', per_page: 5, recursive: true } }
    let(:last_page) { (finder_for(1).total / 5.0).ceil }

    def finder_for(page, **extra)
      described_class.new(project, base_params.merge(page: page, **extra))
    end

    def keyset_pages(count)
      page_token = nil

      Array.new(count) do
        finder = described_class.new(project, base_params.merge(pagination: 'keyset', page_token: page_token))
        finder.execute(gitaly_pagination: true).map(&:path).tap { page_token = finder.next_cursor }
      end
    end

    describe '#later_page_via_gitaly?' do
      it 'is true for a later page within the tree', :aggregate_failures do
        expect(finder_for(2).later_page_via_gitaly?).to be(true)
        expect(finder_for(last_page).later_page_via_gitaly?).to be(true)
        expect(finder_for(2, recursive: false).later_page_via_gitaly?).to be(true)
      end

      it 'is false for the first page and pages past the end', :aggregate_failures do
        expect(finder_for(1).later_page_via_gitaly?).to be(false)
        expect(finder_for(last_page + 1).later_page_via_gitaly?).to be(false)
      end

      where(:case_name, :extra_params, :flag_enabled) do
        'the feature flag is disabled' | {}                                             | false
        'keyset pagination'            | { pagination: 'keyset' }                       | true
        'a page token'                 | { page_token: 'abc' }                          | true
        'per_page above the maximum'   | { per_page: Kaminari.config.max_per_page + 1 } | true
      end

      with_them do
        it 'is false' do
          stub_feature_flags(tree_offset_pagination_gitaly_offset: flag_enabled)

          expect(finder_for(2, **extra_params).later_page_via_gitaly?).to be(false)
        end
      end
    end

    describe '#past_last_page?' do
      it 'is true only for a page past the end of the tree', :aggregate_failures do
        expect(finder_for(last_page + 1).past_last_page?).to be(true)
        expect(finder_for(last_page).past_last_page?).to be(false)
        expect(finder_for(1).past_last_page?).to be(false)
      end

      it 'is false for a missing path' do
        expect(finder_for(2, path: 'missing').past_last_page?).to be(false)
      end

      it 'is false when the feature flag is disabled' do
        stub_feature_flags(tree_offset_pagination_gitaly_offset: false)

        expect(finder_for(last_page + 1).past_last_page?).to be(false)
      end
    end

    describe '#omit_offset_counts?' do
      it 'is false for a later page of a tree below the count limit' do
        expect(finder_for(2).omit_offset_counts?).to be(false)
      end

      context 'when the tree has at least as many entries as the count limit' do
        before do
          stub_const('Kaminari::ActiveRecordRelationMethods::MAX_COUNT_LIMIT', finder_for(1).total)
        end

        it 'is true only for a later page read via Gitaly', :aggregate_failures do
          expect(finder_for(2).omit_offset_counts?).to be(true)
          expect(finder_for(1).omit_offset_counts?).to be(false)
          expect(finder_for(last_page + 1).omit_offset_counts?).to be(false)
        end
      end
    end

    def expect_tree_request(pagination_params)
      allow(repository).to receive(:tree).and_call_original
      expect(repository).to receive(:tree)
        .with(anything, anything, hash_including(pagination_params: pagination_params))
        .and_call_original
    end

    it 'reads a later page with an offset, in the order of keyset pagination' do
      expected_page = keyset_pages(3).last
      expect_tree_request({ limit: 5, page_token: nil, offset: 10 })

      expect(finder_for(3).execute(gitaly_pagination: true).map(&:path)).to eq(expected_page)
    end

    it 'returns no cursor after the last page' do
      finder = finder_for(last_page)
      finder.execute(gitaly_pagination: true)

      expect(finder.next_cursor).to be_blank
    end

    it 'does not send an offset for the first page' do
      expect_tree_request({ limit: 5, page_token: nil })

      finder_for(1).execute(gitaly_pagination: true)
    end
  end

  describe "#total", :use_clean_rails_memory_store_caching do
    subject { tree_finder.total }

    it { is_expected.to be_an(Integer) }

    it "only calculates the total once" do
      expect(repository).to receive(:tree).once.and_call_original

      2.times { tree_finder.total }
    end

    it "builds the cache key once per finder" do
      allow(repository).to receive(:commit).and_call_original
      expect(repository).to receive(:commit).with(no_args).once.and_call_original

      2.times { tree_finder.total }
    end
  end

  describe "#commit_exists?" do
    subject { tree_finder.commit_exists? }

    context "ref exists" do
      let(:params) do
        { ref: project.default_branch }
      end

      it { is_expected.to be(true) }
    end

    context "ref is missing" do
      let(:params) do
        { ref: "nonesuchref" }
      end

      it { is_expected.to be(false) }
    end
  end
end
