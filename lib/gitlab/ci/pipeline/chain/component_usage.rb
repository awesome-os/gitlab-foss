# frozen_string_literal: true

module Gitlab
  module Ci
    module Pipeline
      module Chain
        class ComponentUsage < Chain::Base
          include Gitlab::Utils::StrongMemoize

          def perform!
            return if included_components.empty?

            enqueue_tracking_job
          end

          def break?
            false
          end

          private

          def enqueue_tracking_job
            serialized_components = included_components.filter_map do |component_hash|
              source = component_source(component_hash)
              next unless source

              source.merge('sha' => component_hash[:sha], 'name' => component_hash[:name])
            end

            return if serialized_components.empty?

            ::Ci::Catalog::Resources::TrackComponentUsageWorker.perform_async(
              project.id,
              current_user&.id,
              serialized_components
            )
          rescue StandardError => e
            Gitlab::ErrorTracking.track_exception(e, project_id: project.id)
          end

          # The bundle path never loads the source project, so a bundled component carries its full path
          def component_source(component_hash)
            if component_hash[:project]
              { 'project_id' => component_hash[:project].id }
            elsif component_hash[:full_path]
              { 'full_path' => component_hash[:full_path] }
            end
          end

          def included_components
            command.yaml_processor_result.included_components
          end
          strong_memoize_attr :included_components
        end
      end
    end
  end
end

Gitlab::Ci::Pipeline::Chain::ComponentUsage.prepend_mod
