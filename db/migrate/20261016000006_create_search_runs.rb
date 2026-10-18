class CreateSearchRuns < ActiveRecord::Migration[8.1]
  def change
    create_table :search_runs do |t|
      t.integer :saved_search_id, null: false
      t.boolean :success, null: false, default: true

      t.foreign_key :saved_searches, column: :saved_search_id, primary_key: :id

      t.timestamps
    end

    add_index :search_runs, :saved_search_id

    # Each listing remembers the run that first discovered it (nil for listings
    # stored before run tracking, or by ad-hoc CLI searches).
    add_column :listings, :search_run_id, :integer
    add_index :listings, :search_run_id
    add_foreign_key :listings, :search_runs, column: :search_run_id, primary_key: :id
  end
end
