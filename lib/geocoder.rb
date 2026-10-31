# frozen_string_literal: true

# City lookup and reverse geocoding through OpenStreetMap's Nominatim service.
#
# Free and key-less, so choosing a search location costs no SociaVault credits.
# Results are cached in the database and requests are paced to at most one per
# second, which keeps us within the usage policy:
# https://operations.osmfoundation.org/policies/nominatim/
class Geocoder
  USER_AGENT = 'fbm_alerter/1.0 (self-hosted Facebook Marketplace monitor)'
  CACHE_TTL = 30.days
  # Always ask for the same number of candidates for a given query, so the
  # cached payload can serve both the picker (5) and the top-match fallback (1).
  SEARCH_LIMIT = 5
  # Nominatim's absolute maximum is 1 request/second. The small margin avoids
  # a burst when two tabs (or a page load and a lookup) land together. Tests
  # make many stubbed requests, so they skip the wait.
  MIN_INTERVAL = ENV['RUBY_ENV'] == 'test' ? 0 : 1.1

  # Standard USPS abbreviations → full state name. Used by
  # `normalize_location` so that "Austin, TX" and "Austin, Texas" resolve to
  # the same cache key.
  STATE_ABBREVS = {
    'AL' => 'Alabama',   'AK' => 'Alaska',    'AZ' => 'Arizona',   'AR' => 'Arkansas',
    'CA' => 'California', 'CO' => 'Colorado',  'CT' => 'Connecticut', 'DE' => 'Delaware',
    'FL' => 'Florida',   'GA' => 'Georgia',   'HI' => 'Hawaii',    'ID' => 'Idaho',
    'IL' => 'Illinois',  'IN' => 'Indiana',   'IA' => 'Iowa',      'KS' => 'Kansas',
    'KY' => 'Kentucky',  'LA' => 'Louisiana', 'ME' => 'Maine',     'MD' => 'Maryland',
    'MA' => 'Massachusetts', 'MI' => 'Michigan', 'MN' => 'Minnesota', 'MS' => 'Mississippi',
    'MO' => 'Missouri',  'MT' => 'Montana',   'NE' => 'Nebraska',  'NV' => 'Nevada',
    'NH' => 'New Hampshire', 'NJ' => 'New Jersey', 'NM' => 'New Mexico', 'NY' => 'New York',
    'NC' => 'North Carolina', 'ND' => 'North Dakota', 'OH' => 'Ohio', 'OK' => 'Oklahoma',
    'OR' => 'Oregon',    'PA' => 'Pennsylvania', 'RI' => 'Rhode Island', 'SC' => 'South Carolina',
    'SD' => 'South Dakota', 'TN' => 'Tennessee', 'TX' => 'Texas',   'UT' => 'Utah',
    'VT' => 'Vermont',   'VA' => 'Virginia',  'WA' => 'Washington', 'WV' => 'West Virginia',
    'WI' => 'Wisconsin', 'WY' => 'Wyoming',   'DC' => 'District of Columbia'
  }.freeze

  # A forward lookup candidate. `name` is the compact label we store on a
  # saved search ("Austin, Texas"); `display_name` is Nominatim's fuller label
  # used to tell ambiguous matches apart in the picker.
  Place = Data.define(:name, :lat, :long, :display_name)

  @mutex = Mutex.new
  @last_request_at = nil

  class << self
    # Resolve coordinates to a human-readable place name.
    # @param lat [Numeric, nil]
    # @param long [Numeric, nil]
    # @return [String, nil] e.g. "Santa Barbara, California", or nil on failure
    def reverse(lat:, long:)
      return nil if lat.nil? || long.nil?

      data = fetch_reverse(lat: lat, long: long)
      data.is_a?(Hash) ? place_name(data) : nil
    end

    # Look up cities, ZIP codes and other places by text.
    # @param query [String]
    # @param limit [Integer]
    # @return [Array<Place>]
    def search(query:, limit: 5)
      query = query.to_s.strip
      return [] if query.empty?

      # Use the normalized form (state abbreviations expanded) as the cache key
      # so that "Austin, TX" and "Austin, Texas" share a single entry.
      cache_key = normalize_location(query).downcase
      cached = GeocodeCache.read(cache_key)
      if cached
        # Build a Place from the cached coordinates — we need the original
        # display_name from Nominatim for disambiguation, so we fall back to
        # a basic Place when the cache only has lat/lon.
        return [Place.new(name: cache_key, lat: cached[:lat], long: cached[:lon], display_name: cache_key)]
      end

      data = request_forward(query: cache_key)
      return [] unless data.is_a?(Array)

      first = build_place(data.first)
      return [] unless first

      GeocodeCache.write(cache_key, { lat: first.lat, lon: first.long })
      [first].first(limit)
    end

    # Normalize a city-state string so that abbreviations and full names
    # collide on the same cache key: "Austin, TX" and "Austin, Texas" both
    # become "austin, texas".
    def normalize_location(city_state)
      parts = city_state.strip.split(',').map(&:strip)
      city = parts[0]&.capitalize
      state = if parts[1] && STATE_ABBREVS[parts[1].upcase]
                STATE_ABBREVS[parts[1].upcase]
              else
                parts[1]&.capitalize
              end
      state ? "#{city}, #{state}" : city
    end

    private

    # Forward geocode request to Nominatim — cached via GeocodeCache.
    def request_forward(query:)
      throttle!

      response = HTTParty.get(
        "#{Config.nominatim_url}/search",
        query: {
          format: 'jsonv2',
          q: query,
          addressdetails: 1,
          limit: SEARCH_LIMIT
        },
        headers: {
          'User-Agent' => USER_AGENT,
          'Accept-Language' => 'en'
        },
        timeout: 5
      )

      return nil unless response.code == 200

      response.parsed_response
    rescue StandardError
      nil
    end

    # Reverse geocode request to Nominatim — no caching (one-time call per search).
    def fetch_reverse(lat:, long:)
      throttle!

      response = HTTParty.get(
        "#{Config.nominatim_url}/reverse",
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

      response.parsed_response
    rescue StandardError
      nil
    end

    def throttle!
      return unless MIN_INTERVAL.positive?

      @mutex.synchronize do
        now = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        if @last_request_at
          wait = MIN_INTERVAL - (now - @last_request_at)
          sleep(wait) if wait.positive?
        end
        @last_request_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      end
    end

    def place_name(data)
      address = data['address'].is_a?(Hash) ? data['address'] : {}
      locality = address['city'] || address['town'] || address['village'] ||
                 address['hamlet'] || address['municipality'] || address['county']
      region = address['state'] || address['country']

      locality = locality&.sub(/\s+County\z/i, '')
      parts = [locality, region].map { |part| part.to_s.strip }.reject(&:empty?).uniq
      return parts.join(', ') if parts.any?

      data['display_name']
    end

    # Prefer "City, State" for the stored label; fall back to the full display
    # name for state/country-level matches, where a two-part label is empty.
    def build_place(data)
      return nil unless data.is_a?(Hash)

      lat = data['lat']
      long = data['lon']
      return nil if lat.nil? || long.nil?

      label = place_name(data).to_s.strip
      label = data['display_name'].to_s.strip if label.empty?
      return nil if label.empty?

      Place.new(
        name: label,
        lat: lat.to_f,
        long: long.to_f,
        display_name: data['display_name'].to_s.strip.presence || label
      )
    end
  end
end
