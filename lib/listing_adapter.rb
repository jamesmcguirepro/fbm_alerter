# frozen_string_literal: true

# Normalizes raw API responses from different sources into ListingObject.
#
# The filter pipeline only ever sees ListingObject, so adding a new source
# (Amazon, eBay, etc.) is a matter of implementing one adapter method —
# the filters remain untouched.
#
# Currently only SociaVault is supported; the module is a thin pass-through.
module ListingAdapter
  class << self
    def from_socia_vault(raw_listing, search_query: nil)
      ListingObject.from_listing_response(response: raw_listing, search_query:)
    end

    # Example future adapter — uncomment and flesh out when a new source lands:
    # def self.from_amazon(raw_listing)
    #   ListingObject.new(
    #     listing_id: raw_listing['asin'],
    #     title:      raw_listing['title'],
    #     price:      raw_listing['price'],
    #     location:   "#{raw_listing['city']}, #{raw_listing['state']}",
    #     url:        raw_listing['url'],
    #     image_url:  raw_listing['image_url'],
    #     listed_at:  Time.parse(raw_listing['posted_at']),
    #     first_seen_at: nil,
    #     last_seen_at: nil,
    #     is_sold:    raw_listing['availability'] == 'sold'
    #   )
    # end
  end
end
