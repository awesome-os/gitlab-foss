# frozen_string_literal: true

require 'spec_helper'

RSpec.describe DesignManagement::GitRepository, feature_category: :design_management do
  let_it_be(:container_repo) { DesignManagement::Repository.new(project: create(:project)) }
  let(:git_repository) { container_repo.repository }

  shared_examples 'returns parsed git attributes that enable LFS for all file types' do
    it 'returns patterns that store /designs/** in LFS as non-text files' do
      expect(subject.patterns).to be_a_kind_of(Hash)
      expect(subject.patterns).to have_key('/designs/**')
      expect(subject.patterns['/designs/**']).to eql(
        { "filter" => "lfs", "diff" => "lfs", "merge" => "lfs", "text" => false }
      )
    end
  end

  describe '.container' do
    it 'is of class DesignManagement::Repository' do
      expect(git_repository.container).to be_a_kind_of(DesignManagement::Repository)
    end
  end

  describe "#info_attributes" do
    subject { git_repository.info_attributes }

    include_examples 'returns parsed git attributes that enable LFS for all file types'
  end

  describe '#attributes_at' do
    subject { git_repository.attributes_at }

    include_examples 'returns parsed git attributes that enable LFS for all file types'
  end

  describe '#gitattribute' do
    it 'returns a gitattribute when path has gitattributes' do
      expect(git_repository.gitattribute('/designs/file.txt', 'filter')).to eq('lfs')
    end

    it 'returns nil when path has no gitattributes' do
      expect(git_repository.gitattribute('/invalid/file.txt', 'filter')).to be_nil
    end
  end

  describe '#attributes' do
    it 'confirms that all files are LFS enabled' do
      %w[png zip anything].each do |filetype|
        path = "/#{DesignManagement.designs_directory}/file.#{filetype}"
        attributes = git_repository.attributes(path)

        expect(attributes['filter']).to eq('lfs')
      end
    end
  end

  describe '#create_if_not_exists' do
    let(:container_repo) { create(:design_management_repository, project: project) }

    context 'when the project repository is SHA256' do
      let(:project) { create(:project, :empty_repo, object_format: Repository::FORMAT_SHA256) }

      it 'creates a SHA256 design repository' do
        expect(git_repository.create_if_not_exists).to be(true)
        expect(git_repository.object_format).to eq(Repository::FORMAT_SHA256)
      end
    end

    context 'when the project repository is SHA1' do
      let(:project) { create(:project, :empty_repo) }

      it 'creates a SHA1 design repository' do
        expect(git_repository.create_if_not_exists).to be(true)
        expect(git_repository.object_format).to eq(Repository::FORMAT_SHA1)
      end
    end

    context 'when the project has no repository' do
      let(:project) { create(:project) }

      it 'creates a design repository with the default object format' do
        expect(git_repository.create_if_not_exists).to be(true)
        expect(git_repository.object_format).to eq(Repository::FORMAT_SHA1)
      end
    end

    context 'when the design repository already exists' do
      let(:project) { create(:project, :empty_repo) }

      before do
        git_repository.create_if_not_exists
      end

      it 'does not look up the project object format' do
        expect(project.repository).not_to receive(:object_format)

        expect(git_repository.create_if_not_exists).to be_nil
      end
    end
  end
end
