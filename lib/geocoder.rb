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

      key = format('%.4f,%.4f', lat.to_f, long.to_f)
      data = fetch_json(
        kind: 'reverse',
        query: key,
        path: '/reverse',
        params: {
          format: 'jsonv2',
          lat: lat,
          lon: long,
          zoom: 10,
          addressdetails: 1
        }
      )

      data.is_a?(Hash) ? place_name(data) : nil
    end

    # Look up cities, ZIP codes and other places by text.
    # @param query [String]
    # @param limit [Integer]
    # @return [Array<Place>]
    def search(query:, limit: 5)
      query = query.to_s.strip
      return [] if query.empty?

      data = fetch_json(
        kind: 'search',
        query: query.downcase.gsub(/\s+/, ' '),
        path: '/search',
        params: {
          format: 'jsonv2',
          q: query,
          addressdetails: 1,
          limit: SEARCH_LIMIT
        }
      )

      return [] unless data.is_a?(Array)

      data.filter_map { |item| build_place(item) }.first(limit)
    end

    private

    def fetch_json(kind:, query:, path:, params:)
      cached = GeocodeCacheEntry.read(kind:, query:, ttl: CACHE_TTL)
      if cached
        begin
          parsed = JSON.parse(cached)
          return parsed if cacheable?(kind, parsed)
        rescue JSON::ParserError
          # Ignore a corrupt cache row and fetch a fresh response below.
        end
      end

      data = request(path:, params:)
      return nil if data.nil?

      GeocodeCacheEntry.write(kind:, query:, payload: JSON.generate(data)) if cacheable?(kind, data)
      data
    end

    # Only cache successful payloads. Nominatim can return a 200 with an error
    # object for a coordinate it cannot resolve; retrying that later is better
    # than pinning it for the cache lifetime.
    def cacheable?(kind, data)
      case kind
      when 'search' then data.is_a?(Array)
      when 'reverse' then data.is_a?(Hash) && data['display_name'].present?
      else false
      end
    end

    def request(path:, params:)
      throttle!

      response = HTTParty.get(
        "#{Config.nominatim_url}#{path}",
        query: params,
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
