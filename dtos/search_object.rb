# frozen_string_literal: true

class SearchObject
  def initialize(query:, lat:, long:, min_price:, max_price:, radius_km:, condition:, delivery_method:)
    @query = query
    @lat = lat
    @long = long
    @min_price = min_price
    @max_price = max_price
    @radius_km = radius_km
    @condition = condition
    @delivery_method = delivery_method
    @id = nil
  end

  # @param [SavedSearch] saved_search
  def self.from_saved_search(saved_search:)
    SearchObject.new(
      id: saved_search.id,
      query: saved_search.query,
      lat: saved_search.lat,
      long: saved_search.long,
      min_price: saved_search.min_price,
      max_price: saved_search.max_price,
      radius_km: saved_search.radius_km,
      condition: saved_search.condition,
      delivery_method: saved_search.delivery_method
    )
  end

  attr_reader :id, :query, :lat, :long, :min_price, :max_price, :radius_km, :condition, :delivery_method

  def search_hash
    {
      query: @query,
      lat: @lat,
      long: @long,
      min_price: @min_price,
      max_price: @max_price,
      radius_km: @radius_km,
      condition: @condition,
      delivery_method: @delivery_method
    }
  end
end
