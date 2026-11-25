# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ci::Catalog::BundledResources::ListService, feature_category: :pipeline_composition do
  let_it_be_with_reload(:project) { create(:project, :public) }
  let_it_be_with_reload(:catalog_resource) do
    create(:ci_catalog_resource, project: project, verification_level: :gitlab_maintained)
  end

  let_it_be(:bundled_resource) do
    create(:ci_catalog_bundled_resource, server_fqdn: Gitlab.config.gitlab.server_fqdn, full_path: project.full_path)
  end

  let_it_be(:version) do
    create(:ci_catalog_bundled_resource_version, bundled_resource: bundled_resource, semver: '1.2.0')
  end

  let_it_be(:component) do
    create(:ci_catalog_bundled_resource_component, version: version, name: 'build',
      file_sha256: Base64.strict_encode64(Digest::SHA256.digest('content')))
  end

  let(:listed_names) { execute.payload[:components].pluck(:name) }

  subject(:execute) { described_class.new.execute }

  it 'lists each component by natural key with its digest' do
    expect(execute.payload[:components]).to contain_exactly(
      {
        server_fqdn: Gitlab.config.gitlab.server_fqdn,
        full_path: project.full_path,
        semver: '1.2.0',
        name: 'build',
        file_sha256: Digest::SHA256.hexdigest('content')
      }
    )
  end

  it 'does not list a component without a digest' do
    create(:ci_catalog_bundled_resource_component, version: version, name: 'test')

    expect(listed_names).to contain_exactly('build')
  end

  context 'when the project path has upper case letters' do
    before do
      mixed_case = create(:project, :public, path: 'MixedCase')
      create(:ci_catalog_resource, project: mixed_case, verification_level: :gitlab_maintained)
      mixed_case_resource = create(:ci_catalog_bundled_resource, server_fqdn: Gitlab.config.gitlab.server_fqdn,
        full_path: mixed_case.full_path)
      mixed_case_version = create(:ci_catalog_bundled_resource_version, bundled_resource: mixed_case_resource)
      create(:ci_catalog_bundled_resource_component, version: mixed_case_version, name: 'mixed',
        file_sha256: Base64.strict_encode64(Digest::SHA256.digest('mixed')))
    end

    it 'lists its components' do
      expect(listed_names).to contain_exactly('build', 'mixed')
    end
  end

  context 'when the project is no longer public' do
    before do
      project.update!(visibility_level: Gitlab::VisibilityLevel::PRIVATE)
    end

    it 'does not list its components' do
      expect(execute.payload[:components]).to be_empty
    end
  end

  context 'when the catalog resource is no longer GitLab maintained' do
    before do
      catalog_resource.update!(verification_level: :unverified)
    end

    it 'does not list its components' do
      expect(execute.payload[:components]).to be_empty
    end
  end

  context 'when the project no longer exists' do
    before do
      other = create(:ci_catalog_bundled_resource, server_fqdn: Gitlab.config.gitlab.server_fqdn,
        full_path: 'gone/project')
      other_version = create(:ci_catalog_bundled_resource_version, bundled_resource: other)
      create(:ci_catalog_bundled_resource_component, version: other_version, name: 'gone',
        file_sha256: Base64.strict_encode64(Digest::SHA256.digest('gone')))
    end

    it 'does not list its components' do
      expect(listed_names).to contain_exactly('build')
    end
  end

  context 'when the bundle was synced from another server' do
    before do
      other = create(:ci_catalog_bundled_resource, server_fqdn: 'other.example.com', full_path: project.full_path)
      other_version = create(:ci_catalog_bundled_resource_version, bundled_resource: other)
      create(:ci_catalog_bundled_resource_component, version: other_version, name: 'synced',
        file_sha256: Base64.strict_encode64(Digest::SHA256.digest('synced')))
    end

    it 'does not list its components' do
      expect(listed_names).to contain_exactly('build')
    end
  end
end
