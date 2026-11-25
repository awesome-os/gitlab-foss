# frozen_string_literal: true

class ValidateCiNamespaceMirrorsOrganizationIdNotNull < Gitlab::Database::Migration[2.4]
  disable_ddl_transaction!
  milestone '19.7'

  CONSTRAINT_NAME = 'check_f051ac59d0'

  def up
    validate_not_null_constraint :ci_namespace_mirrors, :organization_id, constraint_name: CONSTRAINT_NAME
  end

  def down
    # no-op
  end
end
