# frozen_string_literal: true

# Forward-geocode cache for city → coordinates lookups.
#
# Uses a unified table where the `primary` flag distinguishes forward
# (text → coords) from reverse (coords → text) entries. This module only
# touches forward entries (`primary: true`), so listing-location lookups
# and user-search-location lookups share the same normalized key and never
# collide with reverse entries whose keys look like coordinate strings.
#
# Cache key format: "austin, texas" (lowercase, state abbreviations expanded)
# TTL: 30 days (same as the old GeocodeCacheEntry).
module GeocodeCache
  TTL = 30.days

  def self.read(city_key)
    return nil if city_key.blank?

    entry = GeocodeCacheEntry.find_by(query: city_key, primary: true)
    return nil unless entry
    return nil if entry.fetched_at < TTL.ago

    { lat: entry.lat.to_f, lon: entry.lon.to_f }
  end

  def self.write(city_key, coords)
    return if city_key.blank? || coords.nil?
    return unless coords[:lat] && coords[:lon]

    entry = GeocodeCacheEntry.find_or_initialize_by(query: city_key, primary: true)
    entry.update!(lat: coords[:lat], lon: coords[:lon], fetched_at: Time.current)
  end
end
