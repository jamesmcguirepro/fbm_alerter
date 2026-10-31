# frozen_string_literal: true

# Distance helpers: unit conversion and haversine distance calculation.
# Saved searches store miles (the unit the UI and Facebook's search URL use);
# the SociaVault API takes kilometres, so the conversion lives here alongside
# the haversine calculation used by the listing distance filter.
module Distance
  class << self
    def miles_to_km(miles)
      return nil if miles.nil?

      miles.to_f * KM_PER_MILE
    end

    # Haversine formula — returns distance in kilometres between two lat/lon
    # pairs, or nil when any coordinate is missing.
    def haversine(lat1, lon1, lat2, lon2)
      return nil if [lat1, lon1, lat2, lon2].any?(&:nil?)

      d_lat = Math::PI / 180 * (lat2 - lat1)
      d_lon = Math::PI / 180 * (lon2 - lon1)
      a = Math.sin(d_lat / 2)**2 +
          Math.cos(lat1 * Math::PI / 180) * Math.cos(lat2 * Math::PI / 180) *
          Math.sin(d_lon / 2)**2
      2 * EARTH_RADIUS_KM * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))
    end
  end

  private

  KM_PER_MILE       = 1.609344
  EARTH_RADIUS_KM   = 6371.0
end
