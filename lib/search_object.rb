# frozen_string_literal: true

class SearchObject
  def initialize(query:, lat:, long:, min_price:, max_price:, condition:, delivery_method:)
    @query = query
    @lat = lat
    @long = long
    @min_price = min_price
    @max_price = max_price
    @condition = condition
    @delivery_method = delivery_method
  end

  attr_reader :query, :lat, :long, :min_price, :max_price, :condition, :delivery_method

  def search_hash
    {
      query: @query,
      lat: @lat,
      long: @long,
      min_price: @min_price,
      max_price: @max_price,
      condition: @condition,
      delivery_method: @delivery_method
    }
  end
end
