class AddListedAtToListings < ActiveRecord::Migration[8.1]
  def change
    # When the ad was actually listed on Marketplace (the API's creation_time),
    # as opposed to first_seen_at, which is when we first saw it. NULL for rows
    # stored before this column existed.
    add_column :listings, :listed_at, :datetime
  end
end
