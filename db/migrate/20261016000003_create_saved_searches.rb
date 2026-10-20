class CreateSavedSearches < ActiveRecord::Migration[8.1]
  def up
    create_table :saved_searches, if_not_exists: true do |t|
      t.string :query
      t.decimal :lat
      t.decimal :long
      t.decimal :min_price
      t.decimal :max_price
      t.integer :radius_km
      t.string :condition
      t.string :delivery_method
      t.string :email

      t.timestamps
    end
  end

  def down
    drop_table :saved_searches, if_exists: true
  end
end
