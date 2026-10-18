class AddActiveAndNameToSavedSearches < ActiveRecord::Migration[8.1]
  def change
    add_column :saved_searches, :active, :boolean, default: true, null: false
    add_column :saved_searches, :name, :string
    add_index :saved_searches, :active
  end
end
