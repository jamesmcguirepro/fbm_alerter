
class SavedSearch < ActiveRecord::Base
  has_many :alerts
  has_many :listings

  def self.add_search(search_object:, email:)
    create!(
      query: search_object.query,
      lat: search_object.lat,
      long: search_object.long,
      min_price: search_object.min_price,
      max_price: search_object.max_price,
      condition: search_object.condition,
      radius_km: search_object.radius_km,
      delivery_method: search_object.delivery_method,
      email:,
    )
  end

  def print_search
    puts "ID: #{id}, query: #{query} (#{lat}, #{long}), price: #{min_price} - #{max_price}, email: #{email}"
  end
end
