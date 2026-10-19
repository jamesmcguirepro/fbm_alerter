# frozen_string_literal: true

require 'time'

class ListingObject < Data.define(
  :listing_id, :title, :price, :location, :url,
  :image_url, :search_query, :listed_at, :first_seen_at, :last_seen_at, :is_sold
)
  def self.from_listing_response(response:, search_query: nil)
    new(
      listing_id: response['id'],
      title: response['title'],
      price: response.dig('price', 'amount'),
      location: response.dig('location', 'display_name'),
      url: response['url'],
      image_url: response.dig('primary_photo', 'url'),
      search_query: search_query,
      listed_at: parse_time(response['creation_time']),
      first_seen_at: nil,
      last_seen_at: nil,
      is_sold: response['is_sold']
    )
  end

  # The API's creation_time (ISO8601 UTC): when the ad was listed, which is not
  # the same as when we first saw it. Returns nil rather than raising if the
  # field is missing or malformed, so one odd listing cannot fail a run.
  def self.parse_time(value)
    return nil if value.nil? || value.to_s.strip.empty?

    Time.parse(value.to_s)
  rescue ArgumentError
    nil
  end
end
