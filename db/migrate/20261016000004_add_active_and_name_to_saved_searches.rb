class AddActiveAndNameToSavedSearches < ActiveRecord::Migration[8.1]
  def up
    add_column :saved_searches, :active, :boolean, default: true, null: false, if_not_exists: true
    add_column :saved_searches, :name, :string, if_not_exists: true
    add_index :saved_searches, :active, if_not_exists: true
  end

  def down
    remove_index :saved_searches, :active, if_exists: true
    remove_column :saved_searches, :name, if_exists: true
    remove_column :saved_searches, :active, if_exists: true
  end
end
