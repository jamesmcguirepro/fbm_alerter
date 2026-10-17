
# == Schema Information
#
# Table name: saved_searches
#
#  id                :integer          not null, primary key
#  active            :boolean          default(TRUE), not null
#  condition         :string
#  deleted_at        :datetime
#  delivery_method   :string
#  email             :string
#  lat               :decimal(, )
#  long              :decimal(, )
#  max_price         :decimal(, )
#  min_price         :decimal(, )
#  name              :string
#  query             :string
#  radius_km         :integer
#  resolved_location :string
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#
class SavedSearch < ActiveRecord::Base
  include Discard::Model

  has_many :alerts
  has_many :listings, through: :alerts
  has_many :search_runs

  # Soft delete via discard. `kept` hides discarded searches, while the row and
  # its alerts and runs all stay put, so the alert history survives. Discard,
  # unlike paranoia, adds no default scope, so joins keep seeing the history.
  self.discard_column = :deleted_at

  attribute :radius_km, default: 65

  # Keep coordinates at ~11 m precision, then drop a stale cached place name.
  before_save :round_coordinates
  before_save :reset_resolved_location, if: :coordinates_changed?

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

  # Resolve and cache a human-readable place name for the coordinates via a
  # free reverse-geocoding service. Returns the name, or nil when unavailable.
  def resolve_location!
    return resolved_location if resolved_location.present?
    return nil unless valid_coordinates?

    name = ReverseGeocoder.lookup(lat: lat.to_f, long: long.to_f)
    update_column(:resolved_location, name) if name.present?
    name
  end

  # Place name for display, falling back to raw coordinates when unresolved.
  def location_label
    return resolved_location if resolved_location.present?
    return nil if lat.nil? || long.nil?

    "#{lat}, #{long}"
  end

  def print_search(io: $stdout)
    io.puts "ID: #{id}, query: #{query} (#{lat}, #{long}), price: #{min_price} - #{max_price}, email: #{email}"
  end

  private

  def round_coordinates
    self.lat = lat.round(4) if lat
    self.long = long.round(4) if long
  end

  def coordinates_changed?
    persisted? && (will_save_change_to_attribute?(:lat) || will_save_change_to_attribute?(:long))
  end

  def reset_resolved_location
    self.resolved_location = nil
  end
end
