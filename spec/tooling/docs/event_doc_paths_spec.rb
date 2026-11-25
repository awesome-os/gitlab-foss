# frozen_string_literal: true

require 'fast_spec_helper'

require_relative '../../../tooling/docs/event_doc_paths'

RSpec.describe Docs::EventDocPaths, feature_category: :tooling do
  describe '.doc_path_for' do
    where(:event_file, :doc_path) do
      [
        ['app/events/ci/pipeline_created_event.rb', 'data/events/ci/pipeline_created_event.yml'],
        ['/root/ee/app/events/security/scan_event.rb', '/root/data/events/security/scan_event.yml'],
        ['domains/cd/app/events/cd/thing_event.rb', 'domains/cd/data/events/cd/thing_event.yml'],
        ['/root/domains/cd/ee/app/events/cd/thing_event.rb', '/root/domains/cd/data/events/cd/thing_event.yml'],
        ['/home/gitlab-ee/app/events/ci/a_event.rb', '/home/gitlab-ee/data/events/ci/a_event.yml']
      ]
    end

    with_them do
      it { expect(described_class.doc_path_for(event_file)).to eq(doc_path) }
    end
  end

  describe '.relative_doc_path' do
    it 'returns the path below data/events/ for top-level and domain docs' do
      expect(described_class.relative_doc_path('/root/data/events/ci/a.yml')).to eq('ci/a.yml')
      expect(described_class.relative_doc_path('/root/domains/cd/data/events/cd/b.yml')).to eq('cd/b.yml')
    end
  end

  describe '.doc_files' do
    let(:root) { Dir.mktmpdir }

    after do
      FileUtils.rm_rf(root)
    end

    it 'lists top-level and domain docs' do
      %w[data/events/ci/a.yml domains/cd/data/events/cd/b.yml domains/cd/ee/app/events/cd/c.rb].each do |path|
        FileUtils.mkdir_p(File.dirname(File.join(root, path)))
        FileUtils.touch(File.join(root, path))
      end

      expect(described_class.doc_files(root))
        .to eq([File.join(root, 'data/events/ci/a.yml'), File.join(root, 'domains/cd/data/events/cd/b.yml')])
    end
  end
end
