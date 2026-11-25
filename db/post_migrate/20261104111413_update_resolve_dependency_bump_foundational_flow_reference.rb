# frozen_string_literal: true

class UpdateResolveDependencyBumpFoundationalFlowReference < Gitlab::Database::Migration[2.4]
  milestone '19.7'

  restrict_gitlab_migration gitlab_schema: :gitlab_main_org

  OLD_REFERENCE = 'resolve_dependency_bump/experimental'
  NEW_REFERENCE = 'resolve_dependency_bump/v1'

  # @note Renamed in place so the ai_catalog_item_consumers rows keep pointing at it.
  #   Post-deployment so code that only knows OLD_REFERENCE never sees the renamed
  #   row; FoundationalFlow::REFERENCE_ALIASES resolves it until then.
  def up
    update_reference(from: OLD_REFERENCE, to: NEW_REFERENCE)
  end

  def down
    update_reference(from: NEW_REFERENCE, to: OLD_REFERENCE)
  end

  private

  def update_reference(from:, to:)
    connection.execute(<<~SQL)
      UPDATE ai_catalog_items
      SET foundational_flow_reference = #{connection.quote(to)},
          updated_at = NOW()
      WHERE foundational_flow_reference = #{connection.quote(from)}
        AND NOT EXISTS (
          SELECT 1
          FROM ai_catalog_items AS existing
          WHERE existing.foundational_flow_reference = #{connection.quote(to)}
            AND existing.organization_id = ai_catalog_items.organization_id
        )
    SQL
  end
end
