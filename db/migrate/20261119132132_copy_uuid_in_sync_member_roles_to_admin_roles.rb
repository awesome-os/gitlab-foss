# frozen_string_literal: true

# Copies member_roles.uuid into admin_roles too, so a custom admin role has the
# same UUID in both tables. See https://gitlab.com/groups/gitlab-org/-/epics/17390
class CopyUuidInSyncMemberRolesToAdminRoles < Gitlab::Database::Migration[2.4]
  include Gitlab::Database::SchemaHelpers

  milestone '19.7'

  FUNCTION_NAME = 'sync_member_roles_to_admin_roles'

  FUNCTION_BODY = <<~SQL
    IF (TG_OP = 'INSERT' OR TG_OP = 'UPDATE') THEN
      IF (NEW.base_access_level IS NULL AND NEW.organization_id IS NOT NULL) THEN
        INSERT INTO admin_roles (id, uuid, name, description, permissions, organization_id, created_at, updated_at)
        VALUES (NEW.id, NEW.uuid, NEW.name, NEW.description, NEW.permissions, NEW.organization_id, NEW.created_at, NEW.updated_at)
        ON CONFLICT (id) DO UPDATE SET
          uuid = EXCLUDED.uuid,
          name = EXCLUDED.name,
          description = EXCLUDED.description,
          permissions = EXCLUDED.permissions,
          organization_id = EXCLUDED.organization_id,
          updated_at = EXCLUDED.updated_at;
      ELSIF (TG_OP = 'UPDATE' AND OLD.base_access_level IS NULL AND OLD.organization_id IS NOT NULL) THEN
        DELETE FROM admin_roles WHERE id = OLD.id;
      END IF;
      RETURN NEW;

    ELSIF (TG_OP = 'DELETE') THEN
      IF (OLD.base_access_level IS NULL AND OLD.organization_id IS NOT NULL) THEN
        DELETE FROM admin_roles WHERE id = OLD.id;
      END IF;
      RETURN OLD;
    END IF;

    RETURN NULL;
  SQL

  PREVIOUS_FUNCTION_BODY = <<~SQL
    IF (TG_OP = 'INSERT' OR TG_OP = 'UPDATE') THEN
      IF (NEW.base_access_level IS NULL AND NEW.organization_id IS NOT NULL) THEN
        INSERT INTO admin_roles (id, name, description, permissions, organization_id, created_at, updated_at)
        VALUES (NEW.id, NEW.name, NEW.description, NEW.permissions, NEW.organization_id, NEW.created_at, NEW.updated_at)
        ON CONFLICT (id) DO UPDATE SET
          name = EXCLUDED.name,
          description = EXCLUDED.description,
          permissions = EXCLUDED.permissions,
          organization_id = EXCLUDED.organization_id,
          updated_at = EXCLUDED.updated_at;
      ELSIF (TG_OP = 'UPDATE' AND OLD.base_access_level IS NULL AND OLD.organization_id IS NOT NULL) THEN
        DELETE FROM admin_roles WHERE id = OLD.id;
      END IF;
      RETURN NEW;

    ELSIF (TG_OP = 'DELETE') THEN
      IF (OLD.base_access_level IS NULL AND OLD.organization_id IS NOT NULL) THEN
        DELETE FROM admin_roles WHERE id = OLD.id;
      END IF;
      RETURN OLD;
    END IF;

    RETURN NULL;
  SQL

  def up
    create_trigger_function(FUNCTION_NAME) { FUNCTION_BODY }
  end

  def down
    create_trigger_function(FUNCTION_NAME) { PREVIOUS_FUNCTION_BODY }
  end
end
