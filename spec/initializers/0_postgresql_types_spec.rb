# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'PostgreSQL registered types' do
  # These can be obtained via SELECT oid, typname from pg_type
  let(:oids) { [28, 194, 1034, 3220, 23, 20] }

  subject(:types) do
    connection = ApplicationRecord.connection_pool.lease_connection
    connection.reload_type_map
    # Rails 8.2 no longer loads every type up front, it looks up OIDs as queries return them
    connection.select_all('SELECT NULL::xid, NULL::pg_node_tree, NULL::aclitem[], NULL::pg_lsn, 1::int4, 1::int8')
    connection.send(:type_map).keys
  end

  it 'includes custom and standard OIDs' do
    expect(types).to include(*oids)
  end

  it 'includes custom and standard types' do
    expect(types).to include('xid', 'pg_node_tree', '_aclitem', 'pg_lsn', 'int4', 'int8')
  end
end
