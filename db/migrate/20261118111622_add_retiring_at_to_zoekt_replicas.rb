# frozen_string_literal: true

class AddRetiringAtToZoektReplicas < Gitlab::Database::Migration[2.4]
  milestone '19.7'

  def change
    add_column :zoekt_replicas, :retiring_at, :datetime_with_timezone
  end
end
