# frozen_string_literal: true

module Gitlab
  module Ci
    module Pipeline
      module Chain
        module Validate
          class Config < Chain::Base
            include Chain::Helpers

            def perform!
              return unless @command.inputs

              if @command.inputs.size > ::Ci::Pipeline::INPUTS_LIMIT
                return error("There cannot be more than #{::Ci::Pipeline::INPUTS_LIMIT} inputs")
              end

              validate_input_value_sizes
            end

            def break?
              @pipeline.errors.any?
            end

            private

            def validate_input_value_sizes
              return unless Feature.enabled?(:ci_pipeline_input_value_size_limit, @command.project)

              name, _value = @command.inputs.find do |_name, value|
                Gitlab::Json.encode(value).bytesize > ::Ci::Pipeline::INPUT_VALUE_SIZE_LIMIT
              end
              return unless name

              limit = ActiveSupport::NumberHelper.number_to_human_size(::Ci::Pipeline::INPUT_VALUE_SIZE_LIMIT)
              error("The value of input `#{name}` cannot be larger than #{limit} as JSON")
            end
          end
        end
      end
    end
  end
end
