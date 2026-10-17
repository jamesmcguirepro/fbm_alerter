# frozen_string_literal: true

class ListingObject < Data.define(
  :listing_id, :title, :price, :location, :url,
  :image_url, :search_query, :first_seen_at, :last_seen_at, :is_sold
)
  def self.from_listing_response(response:, search_query: nil)
    new(
      listing_id: response['id'],
      title: response['title'],
      price: response.dig('price', 'amount'),
      location: response.dig('location', 'display_name'),
      url: response['url'],
      image_url: response.dig('primary_photo', 'url'),
      first_seen_at: nil,
      last_seen_at: nil,
      is_sold: response['is_sold'],
      search_query: search_query
    )
  end
end
