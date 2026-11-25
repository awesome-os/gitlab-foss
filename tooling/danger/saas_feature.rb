# frozen_string_literal: true

require 'yaml'

module Tooling
  module Danger
    module SaasFeature
      # `change_type` can be:
      #   - :added
      #   - :modified
      #   - :deleted
      def files(change_type:)
        files = helper.public_send("#{change_type}_files") # rubocop:disable GitlabSecurity/PublicSend

        files.filter_map { |path| path.start_with?('ee/config/saas_features/') && Found.new(path, helper) }
      end

      class Found
        ATTRIBUTES = %w[name introduced_by_url milestone group].freeze

        attr_reader :path

        def initialize(path, danger_helper)
          @path = path
          @danger_helper = danger_helper
        end

        ATTRIBUTES.each do |attribute|
          define_method(attribute) do
            yaml[attribute]
          end
        end

        def raw
          @raw ||= @danger_helper.file_content(path)
        end

        def group_match_mr_label?(mr_group_label)
          mr_group_label == group
        end

        private

        def yaml
          @yaml ||= YAML.safe_load(raw)
        end
      end
    end
  end
end
