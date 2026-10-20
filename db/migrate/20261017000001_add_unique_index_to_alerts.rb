class AddUniqueIndexToAlerts < ActiveRecord::Migration[8.1]
  def up
    return if index_exists?(:alerts, %i[listing_id search_id], unique: true)

    # Collapse any pre-existing duplicate (listing, search) alerts, keeping the
    # earliest, so the unique index below can be created.
    execute <<~SQL
      DELETE FROM alerts
      WHERE id NOT IN (
        SELECT MIN(id) FROM alerts GROUP BY listing_id, search_id
      )
    SQL

    add_index :alerts, %i[listing_id search_id], unique: true, if_not_exists: true
  end

  def down
    remove_index :alerts, %i[listing_id search_id], if_exists: true
  end
end
