# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::FileFinder, feature_category: :global_search do
  describe '#find' do
    let_it_be(:project) { create(:project, :public, :repository) }

    subject(:file_finder) { described_class.new(project, project.default_branch_or_main) }

    it_behaves_like 'file finder' do
      let(:expected_file_by_path) { 'files/images/wm.svg' }
      let(:expected_file_by_content) { 'CHANGELOG' }
    end

    context 'with inclusive filters' do
      it 'filters by filename and ignores case', :aggregate_failures do
        results = file_finder.find('files filename:wm.svg')
        expect(results.count).to eq(1)

        results = file_finder.find('files filename:Wm.svg')
        expect(results.count).to eq(1)
      end

      it 'filters by path and ignores case', :aggregate_failures do
        results = file_finder.find('white path:images')
        expect(results.count).to eq(2)

        results = file_finder.find('white path:imAGes')
        expect(results.count).to eq(2)
      end

      it 'filters by extension and ignores case', :aggregate_failures do
        results = file_finder.find('files extension:md')
        expect(results.count).to eq(4)

        results = file_finder.find('files extension:MD')
        expect(results.count).to eq(4)
      end
    end

    context 'with exclusive filters' do
      it 'filters by filename' do
        results = file_finder.find('files -filename:wm.svg')

        expect(results.count).to eq(26)
      end

      it 'filters by path' do
        results = file_finder.find('white -path:images')

        expect(results.count).to eq(5)
      end

      it 'filters by extension' do
        results = file_finder.find('files -extension:md')

        expect(results.count).to eq(23)
      end
    end

    context 'with white space in the path' do
      it 'filters by path correctly' do
        results = subject.find('directory path:"with space/README.md"')

        expect(results.count).to eq(1)
      end
    end

    it 'does not cause N+1 query' do
      expect(Gitlab::GitalyClient).to receive(:call).at_most(10).times.and_call_original

      file_finder.find(': filename:wm.svg')
    end

    context 'for protection against ReDOS' do
      # filter is run once for each result returned, Gitaly returns no content matches outside the filtered paths
      it 'utilizes ::Gitlab::UntrustedRegexp for filename filter' do
        query = "PROCESS.md filename:P#{'*' * 50}m"
        expected_regex_value = "(?i)p#{'.*?' * 50}m$"
        expect(::Gitlab::UntrustedRegexp).to receive(:new).with(expected_regex_value).once.and_call_original

        file_finder.find(query)
      end

      it 'utilizes ::Gitlab::UntrustedRegexp for path filter' do
        query = "PROCESS.md path:P#{'*' * 10}m"
        expected_regex_value = "(?i)p#{'.*?' * 10}m"

        expect(::Gitlab::UntrustedRegexp).to receive(:new).with(expected_regex_value).once.and_call_original
        file_finder.find(query)
      end

      it 'utilizes ::Gitlab::UntrustedRegexp for extension filter' do
        query = "PROCESS.md extension:#{'*' * 10}md"
        expected_regex_value = "(?i)\\.#{'.*?' * 10}md$"

        expect(::Gitlab::UntrustedRegexp).to receive(:new).with(expected_regex_value).twice.and_call_original
        file_finder.find(query)
      end
    end

    describe 'content search options' do
      using RSpec::Parameterized::TableSyntax

      where(:query, :pathspecs, :limit) do
        'files'                                 | nil                                              | 5
        'files filename:Wm.svg'                 | [':(icase)*wm.svg']                              | 5
        'files path:images'                     | [':(icase)*images*']                             | 5
        'files extension:md'                    | [':(icase)*.md']                                 | 5
        'files -extension:md'                   | [':(exclude,icase)*.md']                         | 5
        'files path:a* -filename:b?[c]\\'       | [':(icase)*a**', ':(exclude,icase)*b\?\[c]\\\\'] | 5
        'files path:a extension:md -path:b'     | [':(icase)*a*', ':(exclude,icase)*b*']           | nil
        'files filename:ä.md'                   | nil                                              | nil
        'files path:../files'                   | [':(icase)*../files*']                           | 5
        'files -path:./files'                   | [':(exclude,icase)*./files*']                    | 5
        'files -path:/../files'                 | nil                                              | nil
        'files path:files//images'              | nil                                              | nil
        "files path:#{'a' * 1000}"              | nil                                              | nil
        "files #{(1..33).map { |i| "-path:#{i}" }.join(' ')}" | nil                                | nil
      end

      with_them do
        it 'passes the filters and limits to Gitaly' do
          expected_options = {
            limit: limit, gitaly_limit: limit, max_match_bytes: described_class::MAX_MATCH_BYTES, pathspecs: pathspecs
          }

          expect(project.repository).to receive(:search_files_by_content)
            .with('files', file_finder.ref, expected_options.compact).and_call_original

          file_finder.find(query, content_match_cutoff: 5)
        end
      end

      it 'returns the same results as when the filters are applied in Rails only' do
        queries = ['files filename:wm.svg', 'white path:imAGes', 'files extension:MD', 'files -extension:md',
          'white -path:images', 'files path:files extension:md', 'files -path:/../files', 'files -path:./files']

        find_all = -> { queries.map { |query| file_finder.find(query).map { |blob| [blob.path, blob.startline] } } }
        results = find_all.call
        expect(results).to all(be_present)

        stub_feature_flags(limit_basic_blob_search: false)

        expect(results).to eq(find_all.call)
      end

      it 'applies the cutoff to the content matches that pass the filters' do
        queries = ['files extension:md', 'files -extension:md', 'white -path:images']
        content_matches = ->(query, cutoff) do
          file_finder.find(query, content_match_cutoff: cutoff)
            .select { |blob| blob.content_match.present? }
            .map { |blob| [blob.path, blob.startline] }
        end

        results = queries.map { |query| content_matches.call(query, 2) }
        expect(results).to all(have_attributes(size: 2))

        stub_feature_flags(limit_basic_blob_search: false)

        expect(results).to eq(queries.map { |query| content_matches.call(query, nil).first(2) })
      end

      context 'when limit_basic_blob_search is disabled' do
        before do
          stub_feature_flags(limit_basic_blob_search: false)
        end

        it 'passes only the cutoff without filters' do
          expect(project.repository).to receive(:search_files_by_content)
            .with('files', file_finder.ref, { limit: 5 }).and_call_original

          file_finder.find('files', content_match_cutoff: 5)
        end

        it 'passes no cutoff with filters' do
          expect(project.repository).to receive(:search_files_by_content)
            .with('files', file_finder.ref, { limit: nil }).and_call_original

          file_finder.find('files extension:md', content_match_cutoff: 5)
        end
      end
    end

    context 'when there is an exception Gitlab::Git::Repository::NoRepository' do
      let_it_be(:project) { create(:project, :public, :empty_repo) }

      before do
        allow(project.repository).to receive(:search_files_by_regexp).and_raise(Gitlab::Git::Repository::NoRepository)
      end

      it 'returns empty array' do
        expect(file_finder.find('foo')).to be_empty
      end
    end
  end
end
