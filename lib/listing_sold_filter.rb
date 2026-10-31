# frozen_string_literal: true

# Excludes listings that are already sold.
# Optional — can be toggled per search.
class ListingSoldFilter < ListingFilter
  def filter(listing, _search_object)
    !listing.is_sold
  end
end
