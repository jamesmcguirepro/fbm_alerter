class CreateSearchRuns < ActiveRecord::Migration[8.1]
  def up
    create_table :search_runs, if_not_exists: true do |t|
      t.integer :saved_search_id, null: false
      t.boolean :success, null: false, default: true

      t.foreign_key :saved_searches, column: :saved_search_id, primary_key: :id

      t.timestamps
    end

    add_index :search_runs, :saved_search_id, if_not_exists: true

    # Each listing remembers the run that first discovered it (nil for listings
    # stored before run tracking, or by ad-hoc CLI searches).
    add_column :listings, :search_run_id, :integer, if_not_exists: true
    add_index :listings, :search_run_id, if_not_exists: true
    add_foreign_key :listings, :search_runs, column: :search_run_id, primary_key: :id, if_not_exists: true
  end

  def down
    remove_foreign_key :listings, :search_runs, column: :search_run_id, if_exists: true
    remove_index :listings, :search_run_id, if_exists: true
    remove_column :listings, :search_run_id, if_exists: true
    drop_table :search_runs, if_exists: true
  end
end
