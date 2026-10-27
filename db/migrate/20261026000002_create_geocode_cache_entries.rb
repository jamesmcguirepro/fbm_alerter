class CreateGeocodeCacheEntries < ActiveRecord::Migration[8.1]
  def up
    create_table :geocode_cache_entries, if_not_exists: true do |t|
      t.string :kind, null: false
      t.string :query, null: false
      t.text :payload, null: false
      t.datetime :fetched_at, null: false
      t.timestamps
    end

    add_index :geocode_cache_entries, %i[kind query], unique: true, if_not_exists: true
  end

  def down
    drop_table :geocode_cache_entries, if_exists: true
  end
end
