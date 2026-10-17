
# == Schema Information
#
# Table name: saved_searches
#
#  id              :integer          not null, primary key
#  active          :boolean          default(TRUE), not null
#  condition       :string
#  delivery_method :string
#  email           :string
#  lat             :decimal(, )
#  long            :decimal(, )
#  max_price       :decimal(, )
#  min_price       :decimal(, )
#  name            :string
#  query           :string
#  radius_km       :integer
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#
class SavedSearch < ActiveRecord::Base
  has_many :alerts
  has_many :listings, through: :alerts

  attribute :radius_km, default: 65

  validates :lat, numericality: {
    greater_than_or_equal_to: -90, less_than_or_equal_to: 90,
    message: 'must be a number between -90 and 90'
  }
  validates :long, numericality: {
    greater_than_or_equal_to: -180, less_than_or_equal_to: 180,
    message: 'must be a number between -180 and 180'
  }
  validates :radius_km, numericality: {
    greater_than_or_equal_to: 5, less_than_or_equal_to: 1000,
    message: 'must be a number between 5 and 1000 km'
  }

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

  # True when both coordinates are present and within valid bounds. Used to
  # skip saved searches that would otherwise query the API with bad data.
  def valid_coordinates?
    return false if lat.nil? || long.nil?

    lat.to_f.between?(-90, 90) && long.to_f.between?(-180, 180)
  end

  def print_search(io: $stdout)
    io.puts "ID: #{id}, query: #{query} (#{lat}, #{long}), price: #{min_price} - #{max_price}, email: #{email}"
  end
end
