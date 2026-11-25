# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ci::Catalog::BundledResources::FetchService, feature_category: :pipeline_composition do
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
    create(:ci_catalog_bundled_resource_component, version: version, name: 'build').tap do |component|
      component.file = CarrierWaveStringFile.new_file(file_content: '{"format_version":1}', filename: 'build',
        content_type: 'application/json')
      component.file_sha256 = Base64.strict_encode64(Digest::SHA256.digest('{"format_version":1}'))
      component.save!
    end
  end

  let(:params) do
    { server_fqdn: Gitlab.config.gitlab.server_fqdn, full_path: project.full_path, semver: '1.2.0', name: 'build' }
  end

  subject(:execute) { described_class.new(**params).execute }

  shared_examples 'a bundled component that is not found' do
    it 'returns not found', :aggregate_failures do
      expect(execute).to be_error
      expect(execute.reason).to eq(:not_found)
    end
  end

  it 'returns the component with its bundle and metadata', :aggregate_failures do
    expect(execute).to be_success
    expect(execute.payload).to include(
      bundled_resource: bundled_resource,
      version: version,
      component: component,
      content: '{"format_version":1}'
    )
  end

  context 'when the server is another one' do
    let(:params) { super().merge(server_fqdn: 'other.example.com') }

    it_behaves_like 'a bundled component that is not found'
  end

  context 'when the component does not exist' do
    let(:params) { super().merge(name: 'missing') }

    it_behaves_like 'a bundled component that is not found'
  end

  context 'when the version does not exist' do
    let(:params) { super().merge(semver: '9.9.9') }

    it_behaves_like 'a bundled component that is not found'
  end

  context 'when the component has no digest' do
    before do
      Ci::Catalog::BundledResources::Component.where(id: component.id).update_all(file_sha256: nil)
    end

    it_behaves_like 'a bundled component that is not found'
  end

  context 'when the project is no longer public' do
    before do
      project.update!(visibility_level: Gitlab::VisibilityLevel::PRIVATE)
    end

    it_behaves_like 'a bundled component that is not found'
  end

  context 'when the catalog resource is no longer GitLab maintained' do
    before do
      catalog_resource.update!(verification_level: :unverified)
    end

    it_behaves_like 'a bundled component that is not found'
  end

  context 'when the project no longer exists' do
    let(:params) { super().merge(full_path: 'gone/project') }

    before do
      gone = create(:ci_catalog_bundled_resource, server_fqdn: Gitlab.config.gitlab.server_fqdn,
        full_path: 'gone/project')
      gone_version = create(:ci_catalog_bundled_resource_version, bundled_resource: gone, semver: '1.2.0')
      create(:ci_catalog_bundled_resource_component, version: gone_version, name: 'build',
        file_sha256: Base64.strict_encode64(Digest::SHA256.digest('gone')))
    end

    it_behaves_like 'a bundled component that is not found'
  end
end
