# frozen_string_literal: true

require 'rspec-parameterized'
require "gitlab_quality/test_tooling"

require_relative "../../../../../tooling/lib/tooling/predictive_tests/file_based_selector"

RSpec.describe Tooling::PredictiveTests::FileBasedSelector, feature_category: :tooling do
  using RSpec::Parameterized::TableSyntax

  subject(:result) do
    described_class.new(
      changed_files: changed_files,
      recent_changed_files: recent_changed_files,
      added_files: added_files,
      flag_users: ->(flag) { flag_users[flag] },
      definition_specs: -> { definition_specs },
      clickhouse_client: clickhouse_client,
      project_path: 'gitlab-org/gitlab',
      file_exists: ->(path) { existing_files.include?(path) },
      static_specs: ->(files) { files.flat_map { |file| static_specs.fetch(file, []) } }
    ).execute
  end

  let(:clickhouse_client) { instance_double(GitlabQuality::TestTooling::ClickHouse::Client) }
  let(:rows) { [] }
  let(:recent_changed_files) { [] }
  let(:added_files) { [] }
  let(:flag_users) { {} }
  let(:static_specs) { {} }
  let(:yaml_files) { {} }
  let(:definition_specs) { [] }
  let(:existing_files) { rows.map { |row| row['test_file'] } + changed_files }
  let(:map_age) { 3600 }

  before do
    allow(clickhouse_client).to receive(:query).with(/dateDiff/, any_args).and_return([{ 'age' => map_age }])
    allow(clickhouse_client).to receive(:query).with(/test_files_by_source_file/, any_args).and_return(rows)
    allow(YAML).to receive(:safe_load_file) { |path, **| yaml_files[path] }
  end

  context 'when the newest capture is older than 6 hours' do
    let(:changed_files) { %w[app/models/user.rb] }
    let(:map_age) { 7 * 3600 }

    it 'asks for the full suite' do
      expect(result.full_suite_reason).to include('map is stale: newest capture is 7 hours old')
      expect(result.specs).to be_empty
    end
  end

  context 'when the MR also changes a spec file' do
    let(:changed_files) { %w[app/models/user.rb spec/models/user_spec.rb spec/models/other_spec.rb] }
    let(:rows) { [{ 'source_file' => 'app/models/user.rb', 'test_file' => 'spec/models/user_spec.rb' }] }

    it 'adds the changed spec once, even when the map does not list it' do
      expect(result.specs).to eq(%w[spec/models/other_spec.rb spec/models/user_spec.rb])
    end
  end

  context 'when files inside a domain change' do
    let(:changed_files) { %w[domains/cd/ee/app/models/a.rb domains/cd/spec/models/b_spec.rb] }
    let(:rows) do
      [{ 'source_file' => 'domains/cd/ee/app/models/a.rb', 'test_file' => 'domains/cd/ee/spec/models/a_spec.rb' }]
    end

    it 'selects the specs from the map and the changed spec', :aggregate_failures do
      expect(result.full_suite_reason).to be_nil
      expect(result.specs).to eq(%w[domains/cd/ee/spec/models/a_spec.rb domains/cd/spec/models/b_spec.rb])
    end
  end

  context 'when a spec from the map was deleted' do
    let(:changed_files) { %w[app/models/user.rb] }
    let(:rows) do
      [
        { 'source_file' => 'app/models/user.rb', 'test_file' => 'spec/models/user_spec.rb' },
        { 'source_file' => 'app/models/user.rb', 'test_file' => 'spec/models/gone_spec.rb' }
      ]
    end

    let(:existing_files) { %w[spec/models/user_spec.rb] }

    it 'drops the deleted spec' do
      expect(result.specs).to eq(%w[spec/models/user_spec.rb])
    end
  end

  context 'when a changed source file has map rows and the map is fresh' do
    let(:changed_files) { %w[app/models/user.rb] }
    let(:rows) { [{ 'source_file' => 'app/models/user.rb', 'test_file' => 'spec/models/user_spec.rb' }] }

    it 'selects the specs from the map' do
      expect(result.full_suite_reason).to be_nil
      expect(result.specs).to eq(%w[spec/models/user_spec.rb])
    end
  end

  context 'when system specs would be selected' do
    let(:changed_files) { %w[app/models/user.rb spec/features/users_spec.rb] }
    let(:recent_changed_files) { %w[ee/spec/features/epics_spec.rb] }
    let(:rows) do
      [
        { 'source_file' => 'app/models/user.rb', 'test_file' => 'spec/models/user_spec.rb' },
        { 'source_file' => 'app/models/user.rb', 'test_file' => 'spec/features/profile_spec.rb' },
        { 'source_file' => 'app/models/user.rb', 'test_file' => 'domains/cd/spec/features/cd/environments_spec.rb' }
      ]
    end

    let(:existing_files) { rows.map { |row| row['test_file'] } + changed_files + recent_changed_files }

    it 'leaves them out' do
      expect(result.full_suite_reason).to be_nil
      expect(result.specs).to eq(%w[spec/models/user_spec.rb])
    end
  end

  context 'when only frontend files change' do
    let(:changed_files) { %w[app/assets/javascripts/a.vue spec/frontend/a_spec.js] }

    it 'selects nothing and does not ask for the full suite' do
      expect(result.specs).to be_empty
      expect(result.full_suite_reason).to be_nil
      expect(clickhouse_client).not_to have_received(:query)
    end
  end

  context 'when a Vue 3 migration file changes' do
    where(:changed_file) do
      %w[
        app/assets/javascripts/pages/projects/jobs/show/vue3_migration.yml
        app/assets/javascripts/sentry/vue3_migration.yml
        ee/app/assets/javascripts/pages/foo/bar/index.js
      ]
    end

    with_them do
      let(:changed_files) { [changed_file] }

      it 'asks for the full suite' do
        expect(result.full_suite_reason).to include(changed_file)
      end
    end
  end

  context 'when a generated file changes' do
    where(:generated_file) do
      %w[
        locale/gitlab.pot
        public/-/graphql/introspection_result.json
        public/-/graphql/introspection_result_no_deprecated.json
        doc/api/openapi/openapi_v3.yaml
        config/routing/gitlab_routes.json
      ]
    end

    with_them do
      let(:changed_files) { ['app/models/user.rb', generated_file] }
      let(:rows) { [{ 'source_file' => 'app/models/user.rb', 'test_file' => 'spec/models/user_spec.rb' }] }

      it 'selects the specs from the map' do
        expect(result.full_suite_reason).to be_nil
        expect(result.specs).to eq(%w[spec/models/user_spec.rb])
      end
    end
  end

  context 'when a lint settings file changes' do
    where(:lint_file) do
      %w[
        .rubocop_todo/rspec/be_eq.yml
        scripts/lint/keela_baseline.yml
        scripts/lint/keela_excluded.yml
        .haml-lint.yml
        .markdownlint-cli2.yaml
        gems/config/rubocop.yml
      ]
    end

    with_them do
      let(:changed_files) { ['app/models/user.rb', lint_file] }
      let(:rows) { [{ 'source_file' => 'app/models/user.rb', 'test_file' => 'spec/models/user_spec.rb' }] }

      it 'selects the specs from the map' do
        expect(result.full_suite_reason).to be_nil
        expect(result.specs).to eq(%w[spec/models/user_spec.rb])
      end
    end
  end

  context 'when a Ruby file outside app or lib changes' do
    where(:source_file) do
      %w[
        rubocop/cop/gitlab/authz/condition_scope.rb
        tooling/lib/tooling/predictive_tests/file_based_selector.rb
        scripts/pipeline/set_pipeline_name.rb
        danger/plugins/roulette.rb
      ]
    end

    with_them do
      let(:changed_files) { [source_file] }
      let(:rows) { [{ 'source_file' => source_file, 'test_file' => 'spec/tooling/some_spec.rb' }] }

      it 'selects the specs from the map' do
        expect(result.full_suite_reason).to be_nil
        expect(result.specs).to eq(%w[spec/tooling/some_spec.rb])
      end
    end
  end

  context 'when a Ruby file under spec that is not a spec changes' do
    where(:source_file) do
      %w[
        spec/support/helpers/click_house_helpers.rb
        spec/support/shared_examples/requests/api/work_items/discussions_shared_examples.rb
        ee/spec/factories/ai/duo_workflows/workflows.rb
        domains/cd/ee/spec/factories/cd/applications.rb
      ]
    end

    with_them do
      let(:changed_files) { [source_file] }
      let(:rows) { [{ 'source_file' => source_file, 'test_file' => 'spec/models/user_spec.rb' }] }

      it 'selects the specs from the map' do
        expect(result.full_suite_reason).to be_nil
        expect(result.specs).to eq(%w[spec/models/user_spec.rb])
      end
    end
  end

  context 'when a file run only by its own job changes' do
    where(:own_job_file) do
      %w[
        ee/spec/frontend/fixtures/analytics_dashboards_integration.rb
        domains/cd/spec/frontend/fixtures/environments.rb
        domains/cd/ee/spec/frontend/fixtures/environments.rb
        gems/gitlab-diff/Gemfile.lock
        gems/gitlab-diff/.gitignore
        gems/gitlab-diff/.rspec
        gems/gitlab-diff/.rubocop.yml
        vendor/gems/omniauth-gitlab/Gemfile.lock
        ee/spec/frontend/pages/foo/__snapshots__/bar_spec.js.snap
      ]
    end

    with_them do
      let(:changed_files) { ['app/models/user.rb', own_job_file] }
      let(:rows) { [{ 'source_file' => 'app/models/user.rb', 'test_file' => 'spec/models/user_spec.rb' }] }

      it 'selects the specs from the map' do
        expect(result.full_suite_reason).to be_nil
        expect(result.specs).to eq(%w[spec/models/user_spec.rb])
      end
    end
  end

  context 'when a gem CI file changes' do
    let(:changed_files) { %w[gems/gitlab-diff/.gitlab-ci.yml] }

    it 'asks for the full suite' do
      expect(result.full_suite_reason).to eq("files the map can't judge: gems/gitlab-diff/.gitlab-ci.yml")
    end
  end

  context 'when a non-Ruby file under rubocop, tooling, scripts or danger changes' do
    let(:changed_files) { %w[danger/search_gems/Dangerfile] }
    let(:rows) { [{ 'source_file' => 'danger/search_gems/Dangerfile', 'test_file' => 'spec/tooling/some_spec.rb' }] }

    it 'asks for the full suite' do
      expect(result.full_suite_reason).to eq("files the map can't judge: danger/search_gems/Dangerfile")
    end
  end

  context 'when a file the map cannot judge changes' do
    let(:changed_files) { %w[app/models/user.rb Gemfile.lock] }

    it 'asks for the full suite' do
      expect(result.full_suite_reason).to include('Gemfile.lock')
    end
  end

  context 'when the MR adds a file that is not a flag' do
    let(:new_file) { 'config/new_settings.yml' }
    let(:changed_files) { ['app/models/user.rb', new_file] }
    let(:added_files) { [new_file] }
    let(:rows) { [{ 'source_file' => 'app/models/user.rb', 'test_file' => 'spec/models/user_spec.rb' }] }

    it 'asks for the full suite' do
      expect(result.full_suite_reason).to eq("files the map can't judge: #{new_file}")
    end
  end

  context 'when only a JSON schema changes' do
    let(:schema) { 'app/validators/json_schemas/application_setting_rate_limits.json' }
    let(:changed_files) { [schema] }
    let(:rows) { [{ 'source_file' => 'app/models/application_setting.rb', 'test_file' => 'spec/models/as_spec.rb' }] }

    context 'when Ruby and docs name the schema' do
      let(:flag_users) do
        { 'application_setting_rate_limits' => [schema, 'app/models/application_setting.rb', 'doc/api/settings.yaml'] }
      end

      it 'selects the specs for the Ruby that names it', :aggregate_failures do
        expect(result.full_suite_reason).to be_nil
        expect(result.specs).to eq(%w[spec/models/as_spec.rb])
      end
    end

    context 'when only another JSON file names the schema' do
      let(:flag_users) { { 'application_setting_rate_limits' => %w[app/validators/json_schemas/parent.json] } }

      it 'asks for the full suite' do
        expect(result.full_suite_reason).to eq("files the map can't judge: app/validators/json_schemas/parent.json")
      end
    end

    context 'when nothing names the schema' do
      it 'asks for the full suite' do
        expect(result.full_suite_reason).to eq("files the map can't judge: #{schema}")
      end
    end

    context 'when the search finds nothing' do
      let(:flag_users) { { 'application_setting_rate_limits' => [] } }

      it 'asks for the full suite' do
        expect(result.full_suite_reason).to eq("files the map can't judge: #{schema}")
      end
    end
  end

  context 'when only the rspec order list changes' do
    let(:changed_files) { %w[spec/support/rspec_order_todo.yml] }
    let(:flag_users) { { 'rspec_order_todo' => %w[spec/support/rspec_order.rb] } }

    it 'asks for the full suite' do
      expect(result.full_suite_reason).to eq("files the map can't judge: spec/support/rspec_order_todo.yml")
    end
  end

  context 'when only event and metric definitions change' do
    let(:event) { 'config/events/1662373069_projects_render_page.yml' }
    let(:metric) { 'config/metrics/counts_all/20260101000000_count_total_render_page.yml' }
    let(:changed_files) { [event, metric] }
    let(:yaml_files) do
      {
        event => { 'action' => 'render_page' },
        metric => { 'events' => [{ 'name' => 'render_page' }, 'stray'], 'instrumentation_class' => 'RenderMetric' }
      }
    end

    let(:rows) do
      [
        { 'source_file' => 'app/services/page_service.rb', 'test_file' => 'spec/services/page_spec.rb' },
        { 'source_file' => 'lib/render_metric.rb', 'test_file' => 'spec/lib/render_metric_spec.rb' }
      ]
    end

    let(:definition_specs) { %w[spec/config/metrics/every_metric_definition_spec.rb spec/lib/usage_spec.rb] }
    let(:existing_files) { super() + definition_specs.to_a }
    let(:flag_users) do
      {
        '1662373069_projects_render_page' => [],
        '20260101000000_count_total_render_page' => [],
        'render_page' => [event, metric, 'app/services/page_service.rb'],
        'RenderMetric' => %w[lib/render_metric.rb]
      }
    end

    before do
      allow(clickhouse_client).to receive(:query).with(/test_files_by_source_file/, any_args) do |sql, **|
        rows.select { |row| sql.include?("'#{row['source_file']}'") }
      end
    end

    it 'selects the definition specs and the specs for the Ruby named inside the files', :aggregate_failures do
      expect(result.full_suite_reason).to be_nil
      expect(result.specs).to eq(
        (definition_specs + %w[spec/lib/render_metric_spec.rb spec/services/page_spec.rb]).sort
      )
    end

    context 'when only the event changes' do
      let(:changed_files) { [event] }

      it 'selects the specs for the Ruby that uses its action' do
        expect(result.specs).to eq((definition_specs + %w[spec/services/page_spec.rb]).sort)
      end
    end

    context 'when a metric lists its events under options' do
      let(:changed_files) { [metric] }
      let(:rows) do
        [
          { 'source_file' => 'app/services/page_service.rb', 'test_file' => 'spec/services/page_spec.rb' },
          { 'source_file' => 'app/services/count_service.rb', 'test_file' => 'spec/services/count_spec.rb' }
        ]
      end

      let(:yaml_files) { { metric => { 'key_path' => 'counts.render', 'options' => { 'events' => ['render_page'] } } } }
      let(:flag_users) do
        { '20260101000000_count_total_render_page' => [], 'counts.render' => ['app/services/count_service.rb'],
          'render_page' => ['app/services/page_service.rb'] }
      end

      it 'selects the specs for the Ruby that uses the event or key path' do
        expect(result.specs).to eq((definition_specs + %w[spec/services/count_spec.rb spec/services/page_spec.rb]).sort)
      end
    end

    context 'when the event file is not a mapping' do
      let(:changed_files) { [event] }
      let(:rows) { [{ 'source_file' => 'app/services/page_service.rb', 'test_file' => 'spec/services/page_spec.rb' }] }
      let(:yaml_files) { { event => 'render_page' } }
      let(:flag_users) { { '1662373069_projects_render_page' => ['app/services/page_service.rb'] } }

      it 'searches only the file name' do
        expect(result.specs).to eq((definition_specs + %w[spec/services/page_spec.rb]).sort)
      end
    end

    context 'when the event file cannot be read' do
      let(:changed_files) { [event] }

      before do
        allow(YAML).to receive(:safe_load_file).and_raise(Psych::SyntaxError.new(event, 1, 1, 0, 'bad', 'yaml'))
      end

      it 'asks for the full suite' do
        expect(result.full_suite_reason).to eq("files the map can't judge: #{event}")
      end
    end

    context 'when the name search fails' do
      let(:flag_users) { {} }
      let(:changed_files) { [event] }

      it 'asks for the full suite' do
        expect(result.full_suite_reason).to eq("files the map can't judge: #{event}")
      end
    end

    context 'when the definition spec search fails' do
      let(:definition_specs) { nil }

      it 'asks for the full suite' do
        expect(result.full_suite_reason).to eq("files the map can't judge: #{event}, #{metric}")
      end
    end

    context 'when the MR deletes the event' do
      let(:changed_files) { [event] }
      let(:existing_files) { definition_specs }

      it 'asks for the full suite' do
        expect(result.full_suite_reason).to eq("files the map can't judge: #{event}")
      end
    end
  end

  context 'when a feature flag file changes' do
    let(:flag_file) { 'ee/config/feature_flags/beta/new_flag.yml' }
    let(:changed_files) { ['app/models/user.rb', flag_file] }
    let(:rows) { [{ 'source_file' => 'app/models/user.rb', 'test_file' => 'spec/models/user_spec.rb' }] }

    context 'when the MR adds the flag' do
      let(:added_files) { [flag_file] }

      it 'selects the specs from the map' do
        expect(result.full_suite_reason).to be_nil
        expect(result.specs).to eq(%w[spec/models/user_spec.rb])
      end

      context 'when the MR changes no Ruby files' do
        let(:changed_files) { [flag_file] }

        it 'asks for the full suite' do
          expect(result.full_suite_reason).to eq("files the map can't judge: #{flag_file}")
        end
      end
    end

    context 'when the flag is already on master' do
      context 'when Ruby, specs and frontend files name the flag' do
        let(:flag_users) do
          { 'new_flag' => [flag_file, 'app/services/flag_user.rb', 'spec/lib/stubs_flag_spec.rb', 'app/assets/a.vue'] }
        end

        let(:rows) do
          [
            { 'source_file' => 'app/models/user.rb', 'test_file' => 'spec/models/user_spec.rb' },
            { 'source_file' => 'app/services/flag_user.rb', 'test_file' => 'spec/services/flag_user_spec.rb' }
          ]
        end

        let(:existing_files) { super() + %w[spec/lib/stubs_flag_spec.rb] }

        it 'selects the specs for the files that name the flag' do
          expect(result.full_suite_reason).to be_nil
          expect(result.specs).to eq(
            %w[spec/lib/stubs_flag_spec.rb spec/models/user_spec.rb spec/services/flag_user_spec.rb]
          )
        end
      end

      context 'when a view names the flag' do
        let(:flag_users) { { 'new_flag' => %w[app/views/users/show.html.haml] } }

        it 'asks for the full suite' do
          expect(result.full_suite_reason).to eq("files the map can't judge: app/views/users/show.html.haml")
        end
      end

      context 'when only docs and frontend files name the flag' do
        let(:flag_users) { { 'new_flag' => [flag_file, 'doc/user/feature.md', 'app/assets/a.vue'] } }

        it 'asks for the full suite' do
          expect(result.full_suite_reason).to eq("files the map can't judge: #{flag_file}")
        end
      end

      context 'when nothing names the flag' do
        let(:flag_users) { { 'new_flag' => [flag_file] } }

        it 'asks for the full suite' do
          expect(result.full_suite_reason).to eq("files the map can't judge: #{flag_file}")
        end

        context 'when the MR deletes the flag' do
          let(:existing_files) { super() - [flag_file] }

          it 'selects the specs from the map' do
            expect(result.full_suite_reason).to be_nil
            expect(result.specs).to eq(%w[spec/models/user_spec.rb])
          end

          context 'when the MR changes no Ruby files' do
            let(:changed_files) { [flag_file] }

            it 'asks for the full suite' do
              expect(result.full_suite_reason).to eq("files the map can't judge: #{flag_file}")
            end
          end
        end
      end

      context 'when the search for the flag fails' do
        let(:existing_files) { super() - [flag_file] }

        it 'asks for the full suite' do
          expect(result.full_suite_reason).to eq("files the map can't judge: #{flag_file}")
        end
      end
    end

    context 'when the MR moves the flag to another stage' do
      let(:old_flag_file) { 'ee/config/feature_flags/wip/new_flag.yml' }
      let(:changed_files) { ['app/models/user.rb', old_flag_file, flag_file] }
      let(:added_files) { [flag_file] }
      let(:existing_files) { super() - [old_flag_file] }

      context 'when nothing names the flag' do
        let(:flag_users) { { 'new_flag' => [flag_file] } }

        it 'asks for the full suite' do
          expect(result.full_suite_reason).to eq("files the map can't judge: #{flag_file}, #{old_flag_file}")
        end
      end
    end
  end

  context 'when a work item type definition changes' do
    where(:changed_file) do
      %w[
        app/models/work_items/types_framework/system_defined/definitions/task.rb
        ee/app/models/work_items/types_framework/system_defined/definitions/epic.rb
        domains/foo/app/models/work_items/types_framework/system_defined/definitions/task.rb
        domains/foo/ee/app/models/work_items/types_framework/system_defined/definitions/epic.rb
      ]
    end

    with_them do
      let(:changed_files) { [changed_file] }
      let(:rows) { [{ 'source_file' => changed_file, 'test_file' => 'spec/models/work_item_spec.rb' }] }

      it 'asks for the full suite' do
        expect(result.full_suite_reason).to eq("files the map can't judge: #{changed_file}")
        expect(result.specs).to be_empty
      end
    end
  end

  context 'when tests.yml maps a changed source file' do
    let(:changed_files) { %w[lib/api/issues.rb] }
    let(:rows) { [{ 'source_file' => 'lib/api/issues.rb', 'test_file' => 'spec/requests/api/issues_spec.rb' }] }
    let(:static_specs) { { 'lib/api/issues.rb' => %w[spec/services/mcp/tools/schema_defaults_spec.rb] } }
    let(:existing_files) { %w[spec/requests/api/issues_spec.rb spec/services/mcp/tools/schema_defaults_spec.rb] }

    it 'adds the mapped specs to the ones from the map' do
      expect(result.specs).to eq(%w[spec/requests/api/issues_spec.rb spec/services/mcp/tools/schema_defaults_spec.rb])
    end
  end

  context 'when no static mapping is given' do
    subject(:result) do
      described_class.new(
        changed_files: %w[lib/api/issues.rb],
        flag_users: ->(_flag) { [] },
        definition_specs: -> { [] },
        clickhouse_client: clickhouse_client,
        project_path: 'gitlab-org/gitlab'
      ).execute
    end

    let(:rows) { [{ 'source_file' => 'lib/api/issues.rb', 'test_file' => 'spec/requests/api/issues_spec.rb' }] }

    before do
      allow(YAML).to receive(:safe_load_file).and_call_original
    end

    it 'reads tests.yml' do
      expect(result.specs).to include('spec/services/mcp/tools/schema_defaults_spec.rb')
    end
  end

  context 'when a source file has no map rows' do
    let(:changed_files) { %w[app/models/new_thing.rb] }

    it 'asks for the full suite' do
      expect(result.full_suite_reason).to include('app/models/new_thing.rb')
    end
  end

  context 'when the MR adds a Ruby file and its spec' do
    let(:changed_files) { %w[app/models/user.rb app/models/new_thing.rb spec/models/new_thing_spec.rb] }
    let(:added_files) { %w[app/models/new_thing.rb spec/models/new_thing_spec.rb] }
    let(:rows) { [{ 'source_file' => 'app/models/user.rb', 'test_file' => 'spec/models/user_spec.rb' }] }

    it 'selects the new spec and the specs for the other changed files' do
      expect(result.full_suite_reason).to be_nil
      expect(result.specs).to eq(%w[spec/models/new_thing_spec.rb spec/models/user_spec.rb])
    end

    context 'when the file is already on master' do
      let(:added_files) { %w[spec/models/new_thing_spec.rb] }

      it 'asks for the full suite' do
        expect(result.full_suite_reason).to eq('no map rows for: app/models/new_thing.rb')
      end
    end

    context 'when the MR adds no spec for the file' do
      let(:changed_files) { %w[app/models/user.rb app/models/new_thing.rb] }

      it 'asks for the full suite' do
        expect(result.full_suite_reason).to eq('no map rows for: app/models/new_thing.rb')
      end
    end

    context 'when the spec has the same name but sits in another folder' do
      let(:changed_files) { %w[app/services/groups/update_service.rb spec/services/projects/update_service_spec.rb] }
      let(:added_files) { %w[app/services/groups/update_service.rb] }

      it 'asks for the full suite' do
        expect(result.full_suite_reason).to eq('no map rows for: app/services/groups/update_service.rb')
      end
    end
  end

  context 'when master changed after the last capture' do
    let(:changed_files) { %w[app/models/user.rb] }
    let(:rows) do
      [{ 'source_file' => 'app/models/user.rb', 'test_file' => 'spec/models/user_spec.rb' }]
    end

    let(:recent_changed_files) do
      %w[spec/models/new_spec.rb app/models/recent.rb app/assets/javascripts/a.vue]
    end

    let(:existing_files) { %w[spec/models/user_spec.rb spec/models/new_spec.rb] }

    it 'adds the specs changed on master' do
      expect(result.specs).to eq(%w[spec/models/new_spec.rb spec/models/user_spec.rb])
      expect(clickhouse_client).to have_received(:query).with(/test_files_by_source_file/, any_args).once
    end

    context 'when more than 500 specs changed' do
      let(:recent_changed_files) { Array.new(501) { |i| "spec/models/s#{i}_spec.rb" } }

      it 'asks for the full suite' do
        expect(result.full_suite_reason).to include('501 specs changed since the last capture')
      end
    end

    context 'when the last capture is unknown' do
      let(:recent_changed_files) { nil }

      it 'asks for the full suite' do
        expect(result.full_suite_reason).to include("can't tell what changed since the last capture")
      end
    end
  end

  context 'when the MR only changes a spec and the last capture is unknown' do
    let(:changed_files) { %w[spec/models/user_spec.rb] }
    let(:recent_changed_files) { nil }

    it 'selects the spec without asking for the full suite' do
      expect(result.full_suite_reason).to be_nil
      expect(result.specs).to eq(%w[spec/models/user_spec.rb])
    end
  end
end
