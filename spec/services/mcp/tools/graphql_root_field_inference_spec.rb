# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'MCP GraphQL tools that infer the root field', feature_category: :mcp_server do
  # A query can return two root fields only on different calls when one field has
  # `@include(if: $x)` and the other `@skip(if: $x)` on the same variable.
  def exclusive_pair?(fields)
    conditional = %w[include skip]
    conditions = fields.map do |field|
      directive = field.directives.find { |d| conditional.include?(d.name) }
      condition = directive&.arguments&.find { |a| a.name == 'if' }&.value

      [directive&.name, condition.respond_to?(:name) ? condition.name : nil]
    end

    fields.size == 2 && conditions.map { |name, _| name.to_s }.sort == conditional &&
      conditions.map(&:last).uniq.size == 1 && conditions.first.last.present?
  end

  it 'sets operation_name when a query can return more than one root field' do
    [Rails.root.join('app/services/mcp/tools'), Rails.root.join('ee/app/services/mcp/tools')]
      .select(&:exist?).each { |dir| Rails.autoloaders.main.eager_load_dir(dir) }

    offenders = Mcp::Tools::Base::GraphqlTool.descendants.flat_map do |tool|
      next [] if tool.instance_method(:operation_name).owner != Mcp::Tools::Base::GraphqlTool

      tool.available_versions.filter_map do |version|
        next if tool.version_metadata(version)[:operation_name]

        operation = tool.version_metadata(version)[:graphql_operation]
        operation = operation.call if operation.respond_to?(:call)
        next "#{tool.name} #{version} (operation not in metadata)" unless operation

        roots = GraphQL.parse(operation).definitions
          .grep(GraphQL::Language::Nodes::OperationDefinition).first.selections
        "#{tool.name} #{version}" unless roots.one? || exclusive_pair?(roots)
      end
    end

    expect(offenders).to be_empty,
      "These tools can return several root fields; set operation_name: #{offenders}"
  end
end
