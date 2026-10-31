# frozen_string_literal: true

# == Schema Information
#
# Table name: geocode_cache
#
#  id         :integer          not null, primary key
#  query      :string           not null
#  lat        :decimal(10, 6)
#  lon        :decimal(10, 6)
#  primary    :boolean          default(TRUE), not null
#  fetched_at :datetime         not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_geocode_cache_on_query_and_primary  (query,primary) UNIQUE
#
class GeocodeCacheEntry < ActiveRecord::Base
  self.table_name = 'geocode_cache'

  # Legacy forward-geocode lookup (kind: 'search'). Delegates to GeocodeCache.
  # Kept for backwards compatibility with any remaining callers.
  def self.read(kind:, query:, ttl:)
    return nil unless kind == 'search'

    GeocodeCache.read(query)
  end

  # Legacy forward-geocode write (kind: 'search'). Delegates to GeocodeCache.
  # Kept for backwards compatibility with any remaining callers.
  def self.write(kind:, query:, payload:)
    return unless kind == 'search'
    return unless payload

    begin
      data = JSON.parse(payload)
      if data.is_a?(Hash) && data['lat'] && data['lon']
        GeocodeCache.write(query, { lat: data['lat'].to_f, lon: data['lon'].to_f })
      end
    rescue JSON::ParserError
      # Ignore corrupt payloads
    end
  end
end
