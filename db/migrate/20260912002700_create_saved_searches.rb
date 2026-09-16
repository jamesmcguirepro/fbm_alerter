class CreateSavedSearches < ActiveRecord::Migration[8.1]
  def change
    create_table :saved_searches do |t|
      t.string :query
      t.decimal :lat
      t.decimal :long
      t.decimal :min_price
      t.decimal :max_price
      t.integer :condition
      t.string :delivery_method
      t.string :email
    end
  end
end
