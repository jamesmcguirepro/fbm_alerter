class CreateAlerts < ActiveRecord::Migration[8.1]
  def up
    create_table :alerts, if_not_exists: true do |t|
      t.integer :listing_id, null: false
      t.integer :search_id, null: false
      t.datetime :sent_at

      t.foreign_key :listings, column: :listing_id, primary_key: :id
      t.foreign_key :saved_searches, column: :search_id, primary_key: :id

      t.timestamps
    end

    add_index :alerts, :listing_id, if_not_exists: true
    add_index :alerts, :search_id, if_not_exists: true
  end

  def down
    drop_table :alerts, if_exists: true
  end
end
