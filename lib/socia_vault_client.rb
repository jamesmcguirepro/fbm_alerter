# frozen_string_literal: true

require 'time'

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
    # Results are limited to the recency window (Config.date_listed, i.e. the
    # DATE_LISTED env var) and left in the API's default relevance order, then
    # ordered newest-first locally from each listing's own +creation_time+.
    #
    # Deliberately no +sort_by+: Facebook's creation_time_descend order returns
    # the newest listings *regardless of the query*, so asking for "husqvarna te
    # 300" that way returns Camrys and Teslas. The default order is what keeps
    # the query meaningful; the date window keeps it current, and sorting on
    # +creation_time+ here makes it newest-first without losing the match.
    #
    # The API returns roughly 15 listings per page even when +count+ is
    # higher, so pages are followed using the response cursor until the
    # response reports no next page. Listings are de-duplicated by id.
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
    # @param date_listed [String] Recency window (defaults to Config.date_listed)
    # @yield called once for every API request made (each spends a credit), so
    #   callers can account for the spend as it happens
    # @return [Hash] API response containing listings under ['data']['listings']
    def search(query:, lat:, long:, min_price: nil, max_price: nil,
               radius_km: 65, condition: nil, delivery_method: nil, count: 100,
               date_listed: Config.date_listed, &on_request)
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
          date_listed:,
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
        break if cursor.nil? || !more_pages?(parsed)
      end

      { 'data' => { 'listings' => sort_newest_first(all_listings).index_by { |l| l['id'] } } }
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
                     date_listed: Config.date_listed, cursor: nil)
      params = {
        query:,
        lat:,
        lng: long,
        radius_km:,
        count:
      }

      params[:date_listed] = date_listed if date_listed
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

    # Newest first, using each listing's own creation_time. The API's default
    # order is relevance-based — which is what we want for matching — so the
    # recency ordering has to be applied here. Listings without a usable
    # timestamp keep their relative order at the end.
    def sort_newest_first(listings)
      listings.each_with_index
              .sort_by { |listing, index| [-timestamp(listing), index] }
              .map(&:first)
    end

    # creation_time as a float for sorting; unparseable or missing values sort
    # last rather than blowing up the run.
    def timestamp(listing)
      Time.parse(listing['creation_time'].to_s).to_f
    rescue ArgumentError, TypeError
      -Float::INFINITY
    end

    # Whether the API reports another page of results. Responses include
    # +data.has_next_page+ alongside the cursor; without checking it the loop
    # keeps spending credits on ever-looser results. Older responses omit the
    # flag, in which case the cursor alone decides.
    def more_pages?(data)
      return true unless data.is_a?(Hash)

      value = data['has_next_page']
      value = data.dig('data', 'has_next_page') if value.nil?
      return true if value.nil?

      value == true
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
    # Credit safety net: the API reports has_next_page even when the pool is
    # tiny, so paging is bounded rather than trusted (see more_pages?).
    MAX_PAGES = 3
    # The recency window lives in Config (the DATE_LISTED env var, defaulting
    # to the last 7 days): enough to survive a skipped run (a single day's
    # window loses anything that appeared while the host was down), and
    # per-search dedup means only genuinely new ads alert after the first run.
    # Costs the same single credit as a narrower window.
    private_constant :BASE_URL, :ENDPOINT, :CREDITS_ENDPOINT, :MAX_PAGES
  end
end
