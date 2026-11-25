# frozen_string_literal: true

require "base64"

require "active_record"
# The binary attribute types subclass an OID type, and the adapter that defines it
# is otherwise not loaded until the first database connection is made.
require "active_record/connection_adapters/postgresql_adapter"

require_relative "../database"
require_relative "../../database/as_with_materialized"
require_relative "../../database/ascii_table"
require_relative "../../database/connection_timer"
require_relative "../../database/date_time"
require_relative "../../database/read_only_relation"
require_relative "../../database/rename_table_helpers"
require_relative "../../database/sha256_attribute"
require_relative "../../database/sha_attribute"
require_relative "../../database/type/json_pg_safe"
require_relative "../../database/type/jsonb_boolean"
require_relative "../../database/type/jsonb_float"
require_relative "../../database/type/jsonb_integer"
require_relative "../../database/type/tag_list_type"
require_relative "../../database/x509_serial_number_attribute"
