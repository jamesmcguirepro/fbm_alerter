class AddResolvedLocationToSavedSearches < ActiveRecord::Migration[8.1]
  def up
    add_column :saved_searches, :resolved_location, :string, if_not_exists: true
  end

  def down
    remove_column :saved_searches, :resolved_location, if_exists: true
  end
end
