# frozen_string_literal: true

# Thin SociaVault API client for Facebook Marketplace.
#
# Public methods make at most one HTTP request each, so the client only knows
# how to talk to the API. Paging, title matching and credit decisions live in
# SearchService.
class SociaVaultClient
  class << self
    # Fetch one page of Marketplace search results.
    #
    # Results are limited to the recency window (Config.date_listed, i.e. the
    # DATE_LISTED env var) and left in the API's default relevance order.
    #
    # No +sort_by+ is sent on purpose: Facebook's creation_time_descend order
    # returns the newest listings *regardless of the query*, so asking for
    # "husqvarna te 300" that way returns Camrys and Teslas. The default order
    # is what keeps the query meaningful; SearchService re-orders the matches
    # newest-first locally.
    #
    # @param search_object [SearchObject] query and filters
    # @param cursor [String, nil] cursor returned by the previous page
    # @yield called once for the API request (it spends a credit), so callers
    #   can account for the spend as it happens
    # @return [Hash] { listings: [Hash], cursor: String|nil, has_next_page: Boolean }
    def search_page(search_object:, cursor: nil, &on_request)
      return empty_page if Config.dry_run?

      response = HTTParty.get(
        "#{BASE_URL}#{ENDPOINT}",
        query: build_params(search_object:, cursor:),
        headers: { 'X-API-Key' => Config.api_key },
        timeout: 30
      )

      parsed = handle_response(response:)
      on_request&.call

      {
        listings: extract_listings(data: parsed),
        cursor: extract_cursor(data: parsed),
        has_next_page: more_pages?(data: parsed)
      }
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

    # What an empty (or dry-run) search page looks like.
    def empty_page
      { listings: [], cursor: nil, has_next_page: false }
    end

    # Build request parameters from a SearchObject. Saved searches store miles;
    # the API documents its radius in kilometres, so this is the single place
    # the unit changes.
    def build_params(search_object:, cursor: nil, count: 100)
      params = {
        query: search_object.query,
        lat: search_object.lat,
        lng: search_object.long,
        count:
      }

      if search_object.radius_mi
        params[:radius_km] = Distance.miles_to_km(search_object.radius_mi).round
      end

      date_listed = Config.date_listed
      params[:date_listed] = date_listed if date_listed
      params[:cursor] = cursor if cursor
      params[:min_price] = search_object.min_price if search_object.min_price
      params[:max_price] = search_object.max_price if search_object.max_price
      params[:condition] = search_object.condition if search_object.condition
      params[:delivery_method] = search_object.delivery_method if search_object.delivery_method

      params
    end

    # Extract the array of listings from a parsed response hash. The API may
    # return listings either as a hash keyed by id or as an array.
    def extract_listings(data:)
      return [] unless data.is_a?(Hash) && data['data'] && data['data']['listings']

      raw = data['data']['listings']
      raw = raw.values if raw.is_a?(Hash)
      Array(raw)
    end

    # Extract a pagination cursor from a parsed response, checking the common
    # shapes the API may use.
    def extract_cursor(data:)
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

    # Whether the API reports another page of results. Older responses omit the
    # flag, in which case the cursor alone decides.
    def more_pages?(data:)
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
        raise "Bad Request: #{error_message(response)}"
      when 401
        raise 'Authentication Error: Invalid or missing API key'
      when 402
        parsed = safe_parsed(response)
        if parsed.is_a?(Hash)
          raise "Insufficient Credits: Required #{parsed['required']}, " \
                "Available #{parsed['available']}"
        end
        raise "Insufficient Credits: #{response.body}"
      when 500
        raise "500 Server Error: #{error_message(response)}"
      else
        raise "API Error (#{response.code}): #{error_message(response)}"
      end
    end

    # Safely extract an error message from a parsed response.
    #
    # When the API returns non-JSON (e.g. HTML error pages), HTTParty's
    # +parsed_response+ is the raw body string; calling [] on a String
    # with a symbol key would raise NoMethodError.
    def error_message(response)
      parsed = safe_parsed(response)
      parsed.is_a?(Hash) ? (parsed['error'] || response.body) : response.body
    end

    def safe_parsed(response)
      response.parsed_response
    end

    BASE_URL = 'https://api.sociavault.com'
    ENDPOINT = '/v1/scrape/facebook-marketplace/search'
    CREDITS_ENDPOINT = '/v1/credits'
    private_constant :BASE_URL, :ENDPOINT, :CREDITS_ENDPOINT
  end
end
