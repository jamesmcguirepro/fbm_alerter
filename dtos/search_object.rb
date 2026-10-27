# frozen_string_literal: true

class SearchObject < Data.define(
  :query, :lat, :long, :min_price, :max_price,
  :radius_mi, :condition, :delivery_method, :id
)
  def self.from_saved_search(saved_search:)
    new(
      id: saved_search.id,
      query: saved_search.query,
      lat: saved_search.lat,
      long: saved_search.long,
      min_price: saved_search.min_price,
      max_price: saved_search.max_price,
      radius_mi: saved_search.radius_mi,
      condition: saved_search.condition,
      delivery_method: saved_search.delivery_method
    )
  end
end
