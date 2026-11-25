# frozen_string_literal: true

require 'spec_helper'
require_migration!

RSpec.describe CleanupRemainingRepositoryLanguagesLanguageId,
  migration: :gitlab_main_org,
  feature_category: :source_code_management do
  using RSpec::Parameterized::TableSyntax

  let(:repository_languages) { table(:repository_languages) }
  let(:programming_languages) { table(:programming_languages) }
  let(:organization) { table(:organizations).create!(name: 'org', path: 'org') }
  let(:namespace) { table(:namespaces).create!(name: 'group', path: 'group', organization_id: organization.id) }
  let(:ruby) { create_programming_language('Ruby', 326) }
  let(:javascript) { create_programming_language('JavaScript', 183) }
  let(:missing_programming_language_id) { non_existing_record_id }

  before do
    allow(Gitlab).to receive(:com_except_jh?).and_return(false)
  end

  describe '#up' do
    subject(:run_migration) { migrate! }

    context 'when the table contains exactly one NULL row' do
      where(:programming_language_id, :expected_language_ids) do
        ref(:ruby_programming_language_id)    | [326]
        ref(:missing_programming_language_id) | []
      end

      let(:ruby_programming_language_id) { ruby.id }

      with_them do
        it 'repairs or deletes the row without skipping it' do
          create_repository_language(create_project('single'), programming_language_id)

          run_migration

          expect(repository_languages.pluck(:language_id)).to eq(expected_language_ids)
        end
      end
    end

    context 'when a project has valid, resolvable and unresolved rows' do
      it 'fills missing IDs, deletes unresolved rows and preserves existing IDs', :aggregate_failures do
        project = create_project('mixed')
        ruby_row = create_repository_language(project, ruby.id)
        create_repository_language(project, missing_programming_language_id)
        existing_row = create_repository_language(project, javascript.id, language_id: 1)
        existing_attributes = existing_row.reload.attributes

        run_migration

        expect(ruby_row.reload.language_id).to eq(ruby.language_id)
        expect(existing_row.reload.attributes).to eq(existing_attributes)
        expect(repository_languages.count).to eq(2)
      end
    end

    context 'when a project already has the resolved language under another programming language' do
      it 'deletes the duplicate NULL row and preserves the existing row', :aggregate_failures do
        project = create_project('duplicate')
        existing_row = create_repository_language(project, javascript.id, language_id: ruby.language_id)
        existing_attributes = existing_row.reload.attributes
        create_repository_language(project, ruby.id)

        run_migration

        expect(repository_languages.count).to eq(1)
        expect(existing_row.reload.attributes).to eq(existing_attributes)
      end
    end

    context 'when NULL rows span several batches' do
      before do
        stub_const("#{described_class}::BATCH_SIZE", 2)
      end

      it 'handles repeated project IDs and a partial final batch', :aggregate_failures do
        projects = Array.new(3) { |index| create_project("batch-#{index}") }
        ruby_rows = projects.map { |project| create_repository_language(project, ruby.id) }
        projects.first(2).each do |project|
          create_repository_language(project, missing_programming_language_id)
        end

        run_migration

        expect(ruby_rows.map { |row| row.reload.language_id }).to all(eq(ruby.language_id))
        expect(repository_languages.count).to eq(projects.size)
      end
    end

    context 'on GitLab.com' do
      before do
        allow(Gitlab).to receive(:com_except_jh?).and_return(true)
      end

      it 'leaves NULL rows unchanged' do
        project = create_project('gitlab-com')
        create_repository_language(project, ruby.id)
        create_repository_language(project, missing_programming_language_id)

        expect do
          run_migration
        end.not_to change { repository_languages.order(:programming_language_id).map(&:attributes) }
      end
    end

    context 'when no rows have a NULL language_id' do
      it 'skips the batched cleanup', :aggregate_failures do
        project = create_project('clean')
        create_repository_language(project, ruby.id, language_id: ruby.language_id)

        log = ActiveRecord::QueryRecorder.new { run_migration }.log.join

        expect(log).not_to include('WITH missing_languages AS MATERIALIZED')
        expect(log).not_to match(/DELETE FROM "repository_languages"/)
        expect(repository_languages.pluck(:language_id)).to eq([ruby.language_id])
      end
    end
  end

  describe '#down' do
    subject(:reverse_migration) { schema_migrate_down! }

    it 'leaves repository languages unchanged' do
      migrate!
      project = create_project('rollback')
      create_repository_language(project, ruby.id, language_id: ruby.language_id)
      create_repository_language(project, missing_programming_language_id)

      expect do
        reverse_migration
      end.not_to change { repository_languages.order(:programming_language_id).map(&:attributes) }
    end
  end

  def create_project(suffix)
    project_namespace = table(:namespaces).create!(
      name: suffix, path: suffix, organization_id: organization.id, type: 'Project'
    )

    table(:projects).create!(
      namespace_id: namespace.id,
      project_namespace_id: project_namespace.id,
      organization_id: organization.id
    )
  end

  def create_programming_language(name, language_id)
    programming_languages.create!(name: name, color: '#000000', created_at: Time.current, language_id: language_id)
  end

  def create_repository_language(project, programming_language_id, language_id: nil)
    repository_languages.create!(
      project_id: project.id, programming_language_id: programming_language_id, share: 50, language_id: language_id
    )
  end
end
