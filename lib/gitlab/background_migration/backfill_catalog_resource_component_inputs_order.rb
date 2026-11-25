# frozen_string_literal: true

module Gitlab
  module BackgroundMigration
    # Components published before `spec['inputs_order']` was introduced list their inputs in
    # jsonb key order (by length). This re-reads each component's YAML at its version's SHA
    # and records the declared order. See https://gitlab.com/gitlab-org/gitlab/-/work_items/619182.
    class BackfillCatalogResourceComponentInputsOrder < BatchedMigrationJob
      cursor :id

      operation_name :backfill_catalog_resource_component_inputs_order
      feature_category :pipeline_composition

      ComponentRow = Struct.new(:id, :project_id, :name, :sha, :input_names)

      VERSION_SHA = <<~SQL
        SELECT releases.sha
        FROM catalog_resource_versions
        INNER JOIN releases ON releases.id = catalog_resource_versions.release_id
        WHERE catalog_resource_versions.id = catalog_resource_components.version_id
      SQL

      INPUT_NAMES = "ARRAY(SELECT jsonb_object_keys(spec -> 'inputs'))"

      class ProjectRepository < ::ApplicationRecord
        self.table_name = 'project_repositories'
      end

      # Skipped components keep the length order, so each skip is logged to count them afterwards.
      def self.log_skipped(reason, components, project_id: nil, **fields)
        ::Gitlab::BackgroundMigration::Logger.warn(
          Labkit::Fields::LOG_MESSAGE => "Skipped backfilling catalog component inputs order: #{reason}",
          Labkit::Fields::GL_PROJECT_ID => project_id,
          'component_ids' => components.map(&:id),
          **fields
        )
      end

      # Reads the input order that each component of one project declares in its template.
      class TemplateReader
        def initialize(repository, components)
          @repository = repository
          @components = components
        end

        def inputs_orders
          return skip('repository does not exist') unless repository.exists?

          orders = declared_orders(template_blobs)

          unmatched = components.reject { |component| orders.key?(component.id) }
          skip('no matching template', unmatched) if unmatched.any?

          orders
        # Only the display order depends on this data, so one unreadable repository must not fail the migration.
        rescue GRPC::BadStatus, ::Gitlab::Git::BaseError => e # rubocop:disable BackgroundMigration/AvoidSilentRescueExceptions -- logged, and GRPC::Unavailable is re-raised for a retry
          raise if e.is_a?(GRPC::Unavailable)

          skip('unreadable repository', Labkit::Fields::ERROR_TYPE => e.class.name,
            Labkit::Fields::ERROR_MESSAGE => e.message)
        end

        private

        attr_reader :repository, :components

        def skip(reason, skipped = components, **fields)
          BackfillCatalogResourceComponentInputsOrder.log_skipped(
            reason, skipped, project_id: components.first.project_id, **fields
          )

          {}
        end

        def template_blobs
          blob_refs = components.flat_map do |component|
            candidate_paths(component.name).map { |path| [component.sha, path] }
          end

          repository.batch_blobs(blob_refs).index_by { |blob| [blob.commit_id, blob.path] }
        end

        def declared_orders(blobs)
          components.each_with_object({}) do |component, orders|
            component_blobs = candidate_paths(component.name).filter_map { |path| blobs[[component.sha, path]] }
            order = declared_order(component_blobs, component.input_names)

            orders[component.id] = order if order
          end
        end

        # Mirrors the paths matched by `Ci::Catalog::ComponentsProject::TEMPLATE_PATH_REGEX`.
        def candidate_paths(name)
          ["templates/#{name}.yml", "templates/#{name}/template.yml"]
        end

        # The YAML can be changed or missing, and both template paths can exist for one name, which
        # publishes two components with that name. Use an order only when exactly one distinct order
        # declares the stored inputs, so a component never gets the order of its namesake.
        def declared_order(blobs, input_names)
          orders = blobs
            .filter_map { |blob| declared_input_names(blob) }
            .select { |names| names.sort == input_names.sort }
            .uniq

          orders.first if orders.one?
        end

        def declared_input_names(blob)
          result = ::Gitlab::Ci::Config::Yaml::Loader.new(blob.data, filename: blob.path).load_uninterpolated_yaml
          return unless result.valid?

          spec = result.spec
          inputs = spec[:inputs] if spec.is_a?(Hash)
          inputs.keys.map(&:to_s) if inputs.is_a?(Hash)
        end
      end

      def perform
        each_sub_batch do |sub_batch|
          update_inputs_order(inputs_orders(components_without_inputs_order(sub_batch)))
        end
      end

      private

      # The cursor sub-batch is bounded only by its `LIMIT`, so filtering it directly would pull in
      # rows of later sub-batches. Select its ids first, then filter only those rows.
      def components_without_inputs_order(sub_batch)
        sub_batch_ids = ::Gitlab::SQL::CTE.new(:sub_batch_ids, sub_batch.select(:id).limit(sub_batch_size))

        sub_batch.model
          .with(sub_batch_ids.to_arel)
          .where('catalog_resource_components.id IN (SELECT id FROM sub_batch_ids)')
          .where("jsonb_typeof(spec -> 'inputs') = 'object'")
          .where("spec -> 'inputs_order' IS NULL")
          .pluck(:id, :project_id, :name, Arel.sql("(#{VERSION_SHA})"), Arel.sql(INPUT_NAMES))
          .map { |columns| ComponentRow.new(*columns) }
      end

      def inputs_orders(components)
        # With fewer than two inputs there is no order to recover, so Gitaly is not needed.
        trivial, ordered = components.partition { |component| component.input_names.size < 2 }
        orders = trivial.to_h { |component| [component.id, component.input_names] }

        without_sha, ordered = ordered.partition { |component| component.sha.nil? }
        self.class.log_skipped('no release SHA', without_sha) if without_sha.any?

        locations = repository_locations(ordered.map(&:project_id).uniq)

        # Each project needs its own Gitaly calls, which exceeds the per-request limit outside production.
        ::Gitlab::GitalyClient.allow_n_plus_1_calls do
          ordered.group_by(&:project_id).each do |project_id, project_components|
            repository = raw_repository(project_id, project_components, locations[project_id])
            orders.merge!(TemplateReader.new(repository, project_components).inputs_orders) if repository
          end
        end

        orders
      end

      def repository_locations(project_ids)
        return {} if project_ids.empty?

        ProjectRepository
          .joins('INNER JOIN shards ON shards.id = project_repositories.shard_id')
          .where(project_id: project_ids)
          .pluck(:project_id, 'shards.name', :disk_path)
          .to_h { |project_id, shard_name, disk_path| [project_id, [shard_name, disk_path]] }
      end

      def raw_repository(project_id, components, location)
        shard_name, disk_path = location
        reason = if shard_name.nil?
                   'no project repository record'
                 elsif ::Gitlab.config.repositories.storages.keys.map(&:to_s).exclude?(shard_name)
                   'unknown repository storage'
                 end

        return ::Gitlab::Git::Repository.new(shard_name, "#{disk_path}.git", "project-#{project_id}", nil) unless reason

        self.class.log_skipped(reason, components, project_id: project_id, 'repository_storage' => shard_name)
        nil
      end

      def update_inputs_order(orders)
        return if orders.empty?

        values = orders.map do |id, order|
          "(#{Integer(id)}, #{connection.quote(::Gitlab::Json.dump(order))}::jsonb)"
        end

        connection.execute(<<~SQL)
          UPDATE catalog_resource_components
          SET spec = catalog_resource_components.spec || jsonb_build_object('inputs_order', orders.inputs_order)
          FROM (VALUES #{values.join(', ')}) AS orders (id, inputs_order)
          WHERE catalog_resource_components.id = orders.id
            AND catalog_resource_components.spec -> 'inputs_order' IS NULL
        SQL
      end
    end
  end
end
