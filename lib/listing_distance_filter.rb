# frozen_string_literal: true

# Filters out listings that are farther than the search radius from the search
# center. Uses the GeocodeCache (normalized city → coords) to avoid redundant
# geocoding calls.
#
# Listings that cannot be geocoded (city not found, no lat/lon) pass through
# to avoid losing valid listings over a geocoding edge case.
class ListingDistanceFilter < ListingFilter
  attr_reader :radius_km

  # @param radius_km [Float, nil] search radius in kilometres (from SearchObject)
  # @param geocoder [Class] the geocoder class for cache misses (default: Geocoder)
  def initialize(radius_km:, geocoder: Geocoder)
    @radius_km = radius_km
    @geocoder = geocoder
    @geocode_lookups = 0
  end

  def before_search(search_object)
    @search_lat = search_object.lat.to_f
    @search_lon = search_object.long.to_f
  end

  # @return [Boolean] true when the listing is within radius
  def filter(listing, _search_object)
    return true unless listing.location
    return true unless @search_lat && @search_lon

    city_key = normalize_listing_location(listing.location)
    coords   = cache_lookup(city_key) || cache_miss(city_key)
    return true unless coords  # couldn't geocode, pass through (lenient)

    distance = Distance.haversine(@search_lat, @search_lon, coords[:lat], coords[:lon])
    distance <= @radius_km
  end

  def after_search(stats = {})
    return if @geocode_lookups.zero?

    stats[:geocode_lookups] ||= 0
    stats[:geocode_lookups] += @geocode_lookups
  end

  private

  def cache_lookup(city_key)
    @geocode_lookups += 1
    GeocodeCache.read(city_key)
  end

  def cache_miss(city_key)
    result = @geocoder.search(query: city_key).first
    return unless result

    GeocodeCache.write(city_key, { lat: result.lat, lon: result.long })
    { lat: result.lat, lon: result.long }
  end

  # Normalize a SociaVault listing location string to a geocode cache key.
  #
  # Examples:
  #   "US / Austin, TX"              → "austin, texas"
  #   "Austin, Texas"                → "austin, texas"
  #   "dallas, TX"                   → "dallas, texas"
  #   "Austin, Travis County, Texas" → "austin, travis county, texas"
  def normalize_listing_location(location)
    location
         .gsub(/\bUS\s*\/\s*/i, '')   # strip "US / " or "US/" or "US /"
         .gsub(/^\s*\/\s*/, '')        # strip any leftover leading slash
         .strip
         .split(',')
         .map { |part| Geocoder.normalize_location(part.strip) }
         .join(', ')
         .downcase
         .gsub(/\s+/, ' ')
         .strip
  end
end
