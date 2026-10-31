# frozen_string_literal: true

class BackfillMatchTierI < ActiveRecord::Migration[7.1]
  def up
    # Recompute match tier for every listing that has a title and search_query.
    # Uses raw SQL to avoid loading models (which define enums backed by the column).
    listing_ids = select_value(
      "SELECT id FROM listings WHERE title IS NOT NULL AND search_query IS NOT NULL"
    )

    return if listing_ids.nil?

    # Load only the filter classes (no full boot) to avoid enum-loaded column.
    require_relative '../../lib/listing_filter'
    require_relative '../../lib/listing_matcher'

    exec_query(
      "SELECT id, title, search_query FROM listings WHERE title IS NOT NULL AND search_query IS NOT NULL"
    ).each do |row|
      title = row['title'].to_s
      query = row['search_query'].to_s
      next if title.empty? || query.empty?

      matcher = ListingMatcher.new(query: query)
      tier = if matcher.exact_match?(title:)
        2  # exact
      elsif matcher.title_match?(title:)
        1  # partial
      else
        0  # no_match
      end

      exec_query("UPDATE listings SET match_tier = #{tier} WHERE id = #{row['id']}")
    end
  end

  def down
    # Reset all match tiers to no_match (0).
    exec_query("UPDATE listings SET match_tier = 0")
  end
end
