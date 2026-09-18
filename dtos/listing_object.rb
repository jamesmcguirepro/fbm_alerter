# frozen_string_literal: true

class ListingObject
  def initialize(title:, price:, location:, url:, image_url:, search_query:, first_seen_at:, last_seen_at:, is_sold:, listing_id:)
    @title = title
    @price = price
    @location = location
    @url = url
    @image_url = image_url
    @search_query = search_query
    @first_seen_at = first_seen_at
    @last_seen_at = last_seen_at
    @is_sold = is_sold
    @listing_id = listing_id
  end

  # @param [Listing] listing
  def self.from_listing_model(listing:)
    new(
      title: listing['title'],
      price: listing['price'],
      location: listing['location'],
      url: listing['url'],
      image_url: listing['image_url'],
      search_query: listing['search_query'],
      first_seen_at: listing['first_seen_at'],
      last_seen_at: listing['last_seen_at'],
      is_sold: listing['is_sold'],
      listing_id: listing['listing_id']
    )
  end

  attr_reader :title, :price, :location, :url, :image_url, :search_query, :first_seen_at, :last_seen_at, :is_sold, :listing_id
end
