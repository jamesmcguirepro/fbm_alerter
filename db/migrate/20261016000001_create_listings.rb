class CreateListings < ActiveRecord::Migration[8.1]
  def up
    create_table :listings, if_not_exists: true do |t|
      t.string :title, null: false
      t.string :listing_id, null: false
      t.float  :price
      t.string :location
      t.string :url
      t.string :image_url
      t.string :search_query
      t.boolean :is_sold, default: false
      t.datetime :first_seen_at
      t.datetime :last_seen_at

      t.timestamps
    end

    add_index :listings, :listing_id, unique: true, if_not_exists: true
  end

  def down
    drop_table :listings, if_exists: true
  end
end
