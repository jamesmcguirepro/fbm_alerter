class AddDeletedAtToSavedSearches < ActiveRecord::Migration[8.1]
  def change
    # Soft delete. A removed search keeps its alerts, runs and listings, so the
    # alert history survives; the search itself just stops appearing.
    add_column :saved_searches, :deleted_at, :datetime

    add_index :saved_searches, :deleted_at
  end
end
