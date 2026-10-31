# frozen_string_literal: true

class AddMatchTierToListings < ActiveRecord::Migration[7.1]
  def change
    add_column :listings, :match_tier, :string
    add_index :listings, :match_tier
  end
end
