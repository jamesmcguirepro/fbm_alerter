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

  # @param [Hash] response
  # @param [String, nil] search_query
  def self.from_listing_response(response:, search_query: nil)
    new(
      listing_id: response['id'],
      title: response['title'],
      price: response['price']&.dig('amount'),
      location: response['location']&.dig('display_name'),
      url: response['url'],
      image_url: response['primary_photo']&.dig('url'),
      first_seen_at: nil,
      last_seen_at: nil,
      is_sold: response['is_sold'],
      search_query: search_query
    )
  end

  attr_reader :title, :price, :location, :url, :image_url, :search_query, :first_seen_at, :last_seen_at, :is_sold, :listing_id
end
