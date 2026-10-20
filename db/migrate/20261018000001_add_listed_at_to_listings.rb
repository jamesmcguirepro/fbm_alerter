class AddListedAtToListings < ActiveRecord::Migration[8.1]
  def up
    # When the ad was actually listed on Marketplace (the API's creation_time),
    # as opposed to first_seen_at, which is when we first saw it. NULL for rows
    # stored before this column existed.
    add_column :listings, :listed_at, :datetime, if_not_exists: true
  end

  def down
    remove_column :listings, :listed_at, if_exists: true
  end
end
