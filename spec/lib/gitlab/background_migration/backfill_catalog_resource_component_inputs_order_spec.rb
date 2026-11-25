# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::BackgroundMigration::BackfillCatalogResourceComponentInputsOrder,
  feature_category: :pipeline_composition do
  let(:organizations) { table(:organizations) }
  let(:namespaces) { table(:namespaces) }
  let(:projects) { table(:projects) }
  let(:shards) { table(:shards) }
  let(:project_repositories) { table(:project_repositories) }
  let(:releases) { table(:releases) }
  let(:catalog_resources) { table(:catalog_resources) }
  let(:catalog_resource_versions) { table(:catalog_resource_versions) }
  let(:catalog_resource_components) { table(:catalog_resource_components) }

  let(:organization) { organizations.create!(name: 'organization', path: 'organization') }
  let(:namespace) { namespaces.create!(name: 'group', path: 'group', type: 'Group', organization_id: organization.id) }
  let(:project) { create_project('components') }
  let(:catalog_resource) { catalog_resources.create!(project_id: project.id, created_at: Time.current) }

  let(:user) { create(:user) } # rubocop:disable RSpec/FactoriesInMigrationSpecs -- Gitaly commits need a ::User

  # Jsonb returns these by key length (`foo`, `bar_bar`, `baz_baz_baz`), not in the YAML order.
  let(:yaml_order) { %w[baz_baz_baz foo bar_bar] }
  let(:inputs) { yaml_order.index_with { {} } }
  let(:component_yaml) { component_yaml_for(yaml_order) }

  let(:sha) { commit_files({ 'templates/my-component.yml' => component_yaml }) }
  let(:version) { create_version(sha) }
  let!(:component) { create_component(version, name: 'my-component', spec: { 'inputs' => inputs }) }

  let(:sub_batch_size) { 100 }

  subject(:migration) do
    described_class.new(
      start_cursor: [catalog_resource_components.minimum(:id)],
      end_cursor: [catalog_resource_components.maximum(:id)],
      batch_table: :catalog_resource_components,
      batch_column: :id,
      sub_batch_size: sub_batch_size,
      pause_ms: 0,
      connection: ApplicationRecord.connection
    )
  end

  after do
    projects.find_each { |project| raw_repository(project).remove }
  end

  def perform_migration
    migration.perform
  end

  shared_examples 'does not change the spec' do
    it 'does not change the spec' do
      expect { perform_migration }.not_to change { spec_of(component) }
    end
  end

  shared_examples 'skips the component' do |reason|
    it_behaves_like 'does not change the spec'

    it 'logs the skip' do
      allow(Gitlab::BackgroundMigration::Logger).to receive(:warn).and_call_original

      perform_migration

      expect(Gitlab::BackgroundMigration::Logger).to have_received(:warn)
        .with(skip_log(reason, 'component_ids' => [component.id]))
    end
  end

  shared_examples 'records the declared input order' do
    it 'records the declared input order' do
      expect { perform_migration }
        .to change { spec_of(component) }.to('inputs' => inputs, 'inputs_order' => yaml_order)
    end
  end

  it_behaves_like 'records the declared input order'

  it 'is idempotent' do
    perform_migration

    expect { perform_migration }.not_to change { spec_of(component) }
  end

  context 'when the component is defined in a template directory' do
    let(:sha) { commit_files({ 'templates/my-component/template.yml' => component_yaml }) }

    it_behaves_like 'records the declared input order'
  end

  context 'when the YAML was reordered after the version was published' do
    let(:sha) do
      published_sha = commit_files({ 'templates/my-component.yml' => component_yaml })
      commit_files({ 'templates/my-component.yml' => component_yaml_for(yaml_order.reverse) }, action: :update)

      published_sha
    end

    it_behaves_like 'records the declared input order'
  end

  context 'when both template paths exist for the component name' do
    let(:sha) do
      commit_files({
        'templates/my-component.yml' => component_yaml_for(%w[other]),
        'templates/my-component/template.yml' => component_yaml
      })
    end

    it_behaves_like 'records the declared input order'

    context 'when both templates declare the stored inputs in different orders' do
      let(:sha) do
        commit_files({
          'templates/my-component.yml' => component_yaml_for(yaml_order.reverse),
          'templates/my-component/template.yml' => component_yaml
        })
      end

      it_behaves_like 'skips the component', 'no matching template'
    end
  end

  context 'when inputs_order is already set' do
    let(:sha) { 'a' * 40 }
    let!(:component) do
      create_component(version, name: 'my-component',
        spec: { 'inputs' => inputs, 'inputs_order' => %w[foo bar_bar baz_baz_baz] })
    end

    it_behaves_like 'does not change the spec'
  end

  context 'when the spec has no inputs' do
    let(:sha) { 'a' * 40 }
    let!(:component) { create_component(version, name: 'my-component', spec: {}) }

    it_behaves_like 'does not change the spec'
  end

  context 'when the component has fewer than two inputs' do
    let(:sha) { 'a' * 40 }
    let!(:component) { create_component(version, name: 'my-component', spec: { 'inputs' => {} }) }
    let!(:single_input_component) do
      create_component(version, name: 'single', spec: { 'inputs' => { 'foo' => { 'default' => 'bar' } } })
    end

    it 'records the order without reading the repository' do
      allow(Gitlab::Git::Repository).to receive(:new).and_call_original

      perform_migration

      expect(Gitlab::Git::Repository).not_to have_received(:new)

      expect(spec_of(component)['inputs_order']).to eq([])
      expect(spec_of(single_input_component)['inputs_order']).to eq(%w[foo])
    end
  end

  context 'when the release has no SHA' do
    let(:sha) { nil }

    it_behaves_like 'skips the component', 'no release SHA'
  end

  context 'when the component file does not exist at the version SHA' do
    let(:sha) { commit_files({ 'templates/other-component.yml' => component_yaml }) }

    it_behaves_like 'skips the component', 'no matching template'
  end

  context 'when the version SHA does not exist in the repository' do
    let(:sha) { 'a' * 40 }

    it_behaves_like 'skips the component', 'no matching template'
  end

  context 'when the YAML declares different inputs than the stored spec' do
    let(:component_yaml) { component_yaml_for(%w[foo bar_bar]) }

    it_behaves_like 'skips the component', 'no matching template'
  end

  context 'when the YAML is invalid' do
    let(:component_yaml) { "spec:\n  inputs: [\n---\njob:\n  script: echo" }

    it_behaves_like 'skips the component', 'no matching template'
  end

  context 'when the template spec is not a hash' do
    let(:component_yaml) { "spec: [inputs]\n---\njob:\n  script: echo\n" }

    it_behaves_like 'skips the component', 'no matching template'
  end

  context 'when the project repository does not exist' do
    before do
      raw_repository(project).remove
    end

    it_behaves_like 'skips the component', 'repository does not exist'
  end

  context 'when the project has no project_repositories record' do
    before do
      project_repositories.where(project_id: project.id).delete_all
    end

    it_behaves_like 'skips the component', 'no project repository record'
  end

  context 'when components that cannot be backfilled span several sub-batches' do
    let(:sub_batch_size) { 2 }
    let(:sha) { commit_files({ 'templates/other-component.yml' => component_yaml }) }

    let!(:component) do
      create_component(version, name: 'my-component', spec: { 'inputs' => inputs, 'inputs_order' => yaml_order })
    end

    let!(:missing_components) do
      %w[missing-a missing-b].map { |name| create_component(version, name: name, spec: { 'inputs' => inputs }) }
    end

    it 'reads each component only in its own sub-batch' do
      read_component_ids = []
      allow(described_class::TemplateReader).to receive(:new).and_wrap_original do |original, repository, components|
        read_component_ids.concat(components.map(&:id))
        original.call(repository, components)
      end

      perform_migration

      expect(read_component_ids).to eq(missing_components.map(&:id))
    end
  end

  context 'with components from multiple projects and versions' do
    let(:other_project) { create_project('other-components') }
    let(:other_catalog_resource) { catalog_resources.create!(project_id: other_project.id, created_at: Time.current) }
    let(:other_order) { %w[zz a yyy] }

    let!(:other_component) do
      other_sha = commit_files({ 'templates/other.yml' => component_yaml_for(other_order) }, project: other_project)
      other_version = create_version(other_sha, catalog_resource: other_catalog_resource)

      create_component(other_version, name: 'other', spec: { 'inputs' => other_order.index_with { {} } })
    end

    it 'records the order of every component' do
      perform_migration

      expect(spec_of(component)['inputs_order']).to eq(yaml_order)
      expect(spec_of(other_component)['inputs_order']).to eq(other_order)
    end

    it 'is not limited by the Gitaly calls allowed per request' do
      stub_const('Gitlab::GitalyClient::MAXIMUM_GITALY_CALLS', 1)

      Gitlab::SafeRequestStore.ensure_request_store { perform_migration }

      expect(spec_of(component)['inputs_order']).to eq(yaml_order)
      expect(spec_of(other_component)['inputs_order']).to eq(other_order)
    end

    context 'when a project is on an unknown repository storage' do
      before do
        shard = shards.create!(name: 'unknown')
        project_repositories.where(project_id: project.id).update_all(shard_id: shard.id)
      end

      it 'skips that project and records the order of the others' do
        allow(Gitlab::BackgroundMigration::Logger).to receive(:warn).and_call_original

        perform_migration

        expect(Gitlab::BackgroundMigration::Logger).to have_received(:warn).with(
          skip_log('unknown repository storage',
            Labkit::Fields::GL_PROJECT_ID => project.id, 'repository_storage' => 'unknown')
        )
        expect(spec_of(component)).not_to have_key('inputs_order')
        expect(spec_of(other_component)['inputs_order']).to eq(other_order)
      end
    end

    context 'when reading a repository fails' do
      def fail_blob_reads_with(error)
        allow(Gitlab::Git::Blob).to receive(:batch).and_call_original
        allow(Gitlab::Git::Blob).to receive(:batch)
          .with(having_attributes(relative_path: "#{hashed_disk_path(project.id)}.git"), any_args)
          .and_raise(error)
      end

      [GRPC::DeadlineExceeded, GRPC::Internal, Gitlab::Git::CommandError].each do |error_class|
        it "skips that project on #{error_class} and records the order of the others" do
          fail_blob_reads_with(error_class.new('cannot read repository'))
          allow(Gitlab::BackgroundMigration::Logger).to receive(:warn).and_call_original

          perform_migration

          expect(Gitlab::BackgroundMigration::Logger).to have_received(:warn).with(
            skip_log('unreadable repository',
              Labkit::Fields::GL_PROJECT_ID => project.id, Labkit::Fields::ERROR_TYPE => error_class.name)
          )
          expect(spec_of(component)).not_to have_key('inputs_order')
          expect(spec_of(other_component)['inputs_order']).to eq(other_order)
        end
      end

      it 'raises GRPC::Unavailable so the job is retried' do
        fail_blob_reads_with(GRPC::Unavailable.new('Gitaly is unavailable'))

        expect { perform_migration }.to raise_error(GRPC::Unavailable)
      end
    end
  end

  def create_project(path)
    project_namespace = namespaces.create!(
      name: path, path: path, type: 'Project', parent_id: namespace.id, organization_id: organization.id
    )

    project = projects.create!(
      name: path,
      path: path,
      namespace_id: namespace.id,
      project_namespace_id: project_namespace.id,
      organization_id: organization.id,
      storage_version: 2
    )

    shard = shards.find_or_create_by!(name: 'default')
    project_repositories.create!(project_id: project.id, shard_id: shard.id, disk_path: hashed_disk_path(project.id))
    raw_repository(project).create_repository('main')

    project
  end

  def hashed_disk_path(project_id)
    hash = Digest::SHA2.hexdigest(project_id.to_s)

    "@hashed/#{hash[0..1]}/#{hash[2..3]}/#{hash}"
  end

  def raw_repository(project)
    Gitlab::Git::Repository.new('default', "#{hashed_disk_path(project.id)}.git", "project-#{project.id}", nil)
  end

  def commit_files(files, project: self.project, action: :create)
    raw_repository(project).commit_files(
      user,
      branch_name: 'main',
      message: 'Update components',
      actions: files.map { |path, content| { action: action, file_path: path, content: content } }
    ).newrev
  end

  def component_yaml_for(input_names)
    inputs = input_names.map { |name| "    #{name}:\n      default: value" }.join("\n")

    "spec:\n  inputs:\n#{inputs}\n---\njob:\n  script: echo\n"
  end

  def create_version(sha, catalog_resource: self.catalog_resource)
    release = releases.create!(
      project_id: catalog_resource.project_id,
      tag: "v#{releases.count + 1}.0.0",
      sha: sha,
      released_at: Time.current,
      created_at: Time.current,
      updated_at: Time.current
    )

    catalog_resource_versions.create!(
      release_id: release.id,
      catalog_resource_id: catalog_resource.id,
      project_id: catalog_resource.project_id,
      created_at: Time.current
    )
  end

  def create_component(version, name:, spec:)
    catalog_resource_components.create!(
      catalog_resource_id: version.catalog_resource_id,
      version_id: version.id,
      project_id: version.project_id,
      created_at: Time.current,
      name: name,
      spec: spec
    )
  end

  def spec_of(component)
    catalog_resource_components.find(component.id).spec
  end

  def skip_log(reason, fields = {})
    hash_including(
      { Labkit::Fields::LOG_MESSAGE => "Skipped backfilling catalog component inputs order: #{reason}" }.merge(fields)
    )
  end
end
