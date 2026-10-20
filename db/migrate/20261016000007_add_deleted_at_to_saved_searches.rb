class AddDeletedAtToSavedSearches < ActiveRecord::Migration[8.1]
  def up
    # Soft delete. A removed search keeps its alerts, runs and listings, so the
    # alert history survives; the search itself just stops appearing.
    add_column :saved_searches, :deleted_at, :datetime, if_not_exists: true

    add_index :saved_searches, :deleted_at, if_not_exists: true
  end

  def down
    remove_index :saved_searches, :deleted_at, if_exists: true
    remove_column :saved_searches, :deleted_at, if_exists: true
  end
end
