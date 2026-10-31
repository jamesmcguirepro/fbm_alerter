# frozen_string_literal: true

class ReplaceMatchTierWithIntegerEnum < ActiveRecord::Migration[7.1]
  def change
    # Replace the string column with an integer enum.
    # Values: 0 (no match), 1 (partial), 2 (exact).
    remove_column :listings, :match_tier, :string
    add_column :listings, :match_tier, :integer, default: 0, null: false
    add_index :listings, :match_tier
  end
end
