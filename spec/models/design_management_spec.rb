# frozen_string_literal: true

require 'spec_helper'

RSpec.describe DesignManagement, feature_category: :design_management do
  using RSpec::Parameterized::TableSyntax

  describe '.enabled_for?' do
    let(:project) { build(:project) }

    where(:lfs_enabled, :hashed_storage_enabled, :expectation) do
      false | false | false
      true  | false | false
      false | true  | false
      true  | true  | true
    end

    with_them do
      before do
        allow(project).to receive(:lfs_enabled?).and_return(lfs_enabled)
        allow(project).to receive(:hashed_storage?).with(:repository).and_return(hashed_storage_enabled)
      end

      it 'returns true only when LFS and hashed storage are both enabled' do
        expect(described_class.enabled_for?(project)).to be(expectation)
      end
    end
  end

  describe '.repository_for' do
    let_it_be_with_reload(:project) { create(:project) }

    subject(:repository_for) { described_class.repository_for(project) }

    context 'when the project has no design management repository yet' do
      it 'creates one and returns its git repository' do
        expect { repository_for }.to change { DesignManagement::Repository.where(project: project).count }.from(0).to(1)

        expect(repository_for).to be_a(DesignManagement::GitRepository)
        expect(repository_for.container).to eq(project.design_management_repository)
      end
    end

    context 'when the project already has a design management repository' do
      let!(:design_management_repository) { create(:design_management_repository, project: project) }

      it 'does not create another one and returns its git repository' do
        expect { repository_for }.not_to change { DesignManagement::Repository.count }

        expect(repository_for.container).to eq(design_management_repository)
      end
    end

    it 'returns the same object on repeated calls for the same project' do
      first_call = described_class.repository_for(project)

      expect(described_class.repository_for(project)).to be(first_call)
    end
  end
end
