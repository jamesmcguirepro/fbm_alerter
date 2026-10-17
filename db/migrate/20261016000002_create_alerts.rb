class CreateAlerts < ActiveRecord::Migration[8.1]
  def change
    create_table :alerts do |t|
      t.integer :listing_id, null: false
      t.integer :search_id, null: false
      t.datetime :sent_at

      t.foreign_key :listings, column: :listing_id, primary_key: :id
      t.foreign_key :saved_searches, column: :search_id, primary_key: :id

      t.timestamps
    end

    add_index :alerts, :listing_id
    add_index :alerts, :search_id
  end
end
