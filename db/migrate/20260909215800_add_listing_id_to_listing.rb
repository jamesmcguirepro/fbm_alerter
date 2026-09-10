class AddListingIdToListing < ActiveRecord::Migration[8.1]
  def change
    add_column :listings, :listing_id, :string, null: false
    add_index :listings, :listing_id, unique: true
  end
end