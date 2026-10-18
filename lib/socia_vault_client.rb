# frozen_string_literal: true

# SociaVault API client for Facebook Marketplace searches
class SociaVaultClient
  class << self
    # @param [SearchObject] search_object
    # @param [Proc] on_request called once per API request (see #search)
    def search_from_object(search_object:, &on_request)
      search(
        query: search_object.query,
        lat: search_object.lat,
        long: search_object.long,
        min_price: search_object.min_price,
        max_price: search_object.max_price,
        radius_km: search_object.radius_km,
        condition: search_object.condition,
        delivery_method: search_object.delivery_method,
        &on_request
      )
    end

    # Search Facebook Marketplace.
    #
    # The API returns roughly 15 listings per page even when +count+ is
    # higher, so pages are followed using the response cursor until no more
    # results remain. Listings are de-duplicated by id across pages.
    #
    # @param query [String] Search keyword
    # @param lat [Float] Latitude
    # @param long [Float] Longitude
    # @param min_price [Integer] Minimum price
    # @param max_price [Integer] Maximum price
    # @param radius_km [Integer] Search radius in kilometers
    # @param condition [String] Item condition (new, used_like_new, used_good, used_fair)
    # @param delivery_method [String] Delivery method (all, local_pickup, shipping)
    # @param count [Integer] Number of results to request per page
    # @yield called once for every API request made (each spends a credit), so
    #   callers can account for the spend as it happens
    # @return [Hash] API response containing listings under ['data']['listings']
    def search(query:, lat:, long:, min_price: nil, max_price: nil,
               radius_km: 65, condition: nil, delivery_method: nil, count: 100,
               &on_request)
      # No-op at the API call: spend nothing and return what an empty search
      # would have returned. See Config.dry_run?.
      return { 'data' => { 'listings' => {} } } if Config.dry_run?

      all_listings = []
      seen_ids = Set.new
      cursor = nil

      MAX_PAGES.times do
        params = build_params(
          query:,
          lat:,
          long:,
          min_price:,
          max_price:,
          radius_km:,
          condition:,
          delivery_method:,
          count:,
          cursor:
        )

        response = HTTParty.get(
          "#{BASE_URL}#{ENDPOINT}",
          query: params,
          headers: { 'X-API-Key' => Config.api_key },
          timeout: 30
        )

        parsed = handle_response(response:)
        on_request&.call

        listings = extract_listings(parsed)
        break if listings.nil? || listings.empty?

        listings.each do |listing|
          id = listing['id']
          next if id.nil? || seen_ids.include?(id)

          seen_ids.add(id)
          all_listings << listing
        end

        cursor = extract_cursor(parsed)
        break if cursor.nil?
      end

      { 'data' => { 'listings' => all_listings.index_by { |l| l['id'] } } }
    end

    # Remaining credit balance for the account behind the API key.
    # This is an account read, not a scrape, so it spends no credits.
    # @return [Hash] e.g. { 'credits' => 950, 'subscriptionStatus' => 'active' }
    def credits
      response = HTTParty.get(
        "#{BASE_URL}#{CREDITS_ENDPOINT}",
        headers: { 'X-API-Key' => Config.api_key },
        timeout: 10
      )

      handle_response(response:)
    end

    private

    # Build request parameters
    def build_params(query:, lat:, long:, min_price: nil, max_price: nil,
                     radius_km: 65, condition: nil, delivery_method: nil, count: 100,
                     cursor: nil)
      params = {
        query:,
        lat:,
        lng: long,
        radius_km:,
        count:
      }

      params[:cursor] = cursor if cursor
      params[:min_price] = min_price if min_price
      params[:max_price] = max_price if max_price
      params[:condition] = condition if condition
      params[:delivery_method] = delivery_method if delivery_method

      params
    end

    # Extract the array of listings from a parsed response hash. The API may
    # return listings either as a hash keyed by id or as an array.
    def extract_listings(data)
      return [] unless data.is_a?(Hash) && data['data'] && data['data']['listings']

      raw = data['data']['listings']
      raw = raw.values if raw.is_a?(Hash)
      Array(raw)
    end

    # Extract a pagination cursor from a parsed response, checking the common
    # shapes the API may use.
    def extract_cursor(data)
      return nil unless data.is_a?(Hash)

      %w[next_cursor cursor].each do |key|
        value = data[key]
        return value if value.is_a?(String) && !value.empty?

        value = data.dig('data', key)
        return value if value.is_a?(String) && !value.empty?
      end

      paging = data['paging'] || data.dig('data', 'paging')
      if paging.is_a?(Hash)
        value = paging['next'] || paging['cursor']
        return value if value.is_a?(String) && !value.empty?
      end

      nil
    end

    # Handle API response
    def handle_response(response:)
      case response.code
      when 200
        response.parsed_response
      when 400
        raise "Bad Request: #{response.parsed_response['error']}"
      when 401
        raise 'Authentication Error: Invalid or missing API key'
      when 402
        raise "Insufficient Credits: Required #{response.parsed_response['required']}, " \
              "Available #{response.parsed_response['available']}"
      when 500
        raise "500 Server Error: #{response.parsed_response['error']}"
      else
        raise "API Error (#{response.code}): #{response.parsed_response['error'] || response.body}"
      end
    end

    BASE_URL = 'https://api.sociavault.com'
    ENDPOINT = '/v1/scrape/facebook-marketplace/search'
    CREDITS_ENDPOINT = '/v1/credits'
    MAX_PAGES = 10
    private_constant :BASE_URL, :ENDPOINT, :CREDITS_ENDPOINT, :MAX_PAGES
  end
end
