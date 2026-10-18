# frozen_string_literal: true

# Resolves coordinates to a human-readable place name using OpenStreetMap's
# Nominatim service. Free and key-less, so no SociaVault credits are spent.
# Results are cached on the record, keeping requests well within the usage
# policy: https://operations.osmfoundation.org/policies/nominatim/
class ReverseGeocoder
  ENDPOINT = 'https://nominatim.openstreetmap.org/reverse'
  USER_AGENT = 'fbm_alerter/1.0 (self-hosted Facebook Marketplace monitor)'

  class << self
    # @param lat [Numeric, nil]
    # @param long [Numeric, nil]
    # @return [String, nil] e.g. "Santa Barbara, California", or nil on failure
    def lookup(lat:, long:)
      return nil if lat.nil? || long.nil?

      response = HTTParty.get(
        ENDPOINT,
        query: {
          format: 'jsonv2',
          lat: lat,
          lon: long,
          zoom: 10,
          addressdetails: 1
        },
        headers: {
          'User-Agent' => USER_AGENT,
          'Accept-Language' => 'en'
        },
        timeout: 5
      )

      return nil unless response.code == 200

      data = response.parsed_response
      return nil unless data.is_a?(Hash)

      place_name(data)
    rescue StandardError
      nil
    end

    private

    def place_name(data)
      address = data['address'] || {}
      locality = address['city'] || address['town'] || address['village'] ||
                 address['hamlet'] || address['municipality'] || address['county']
      region = address['state'] || address['country']

      locality = locality&.sub(/\s+County\z/i, '')
      parts = [locality, region].map { |part| part.to_s.strip }.reject(&:empty?).uniq
      return parts.join(', ') if parts.any?

      data['display_name']
    end
  end
end
