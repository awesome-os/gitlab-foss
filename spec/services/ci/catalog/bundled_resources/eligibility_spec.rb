# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ci::Catalog::BundledResources::Eligibility, feature_category: :pipeline_composition do
  describe '.eligible?' do
    subject(:eligible) { described_class.eligible?(project) }

    context 'when the project is public and its catalog resource is GitLab maintained' do
      let_it_be(:project) { create(:project, :public) }

      before_all do
        create(:ci_catalog_resource, project: project, verification_level: :gitlab_maintained)
      end

      it { is_expected.to be(true) }
    end

    context 'when the project is public but its repository is private' do
      let_it_be(:project) { create(:project, :public, :repository_private) }

      before_all do
        create(:ci_catalog_resource, project: project, verification_level: :gitlab_maintained)
      end

      it { is_expected.to be(false) }
    end

    context 'when the project is internal' do
      let_it_be(:project) { create(:project, :internal) }

      before_all do
        create(:ci_catalog_resource, project: project, verification_level: :gitlab_maintained)
      end

      it { is_expected.to be(false) }
    end

    context 'when the project is private' do
      let_it_be(:project) { create(:project, :private) }

      before_all do
        create(:ci_catalog_resource, project: project, verification_level: :gitlab_maintained)
      end

      it { is_expected.to be(false) }
    end

    context 'when the catalog resource is not GitLab maintained' do
      let_it_be(:project) { create(:project, :public) }

      before_all do
        create(:ci_catalog_resource, project: project, verification_level: :unverified)
      end

      it { is_expected.to be(false) }
    end

    context 'when the project has no catalog resource' do
      let_it_be(:project) { create(:project, :public) }

      it { is_expected.to be(false) }
    end

    context 'when there is no project' do
      let(:project) { nil }

      it { is_expected.to be(false) }
    end
  end
end
