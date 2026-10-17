class AddResolvedLocationToSavedSearches < ActiveRecord::Migration[8.1]
  def change
    add_column :saved_searches, :resolved_location, :string
  end
end
