# frozen_string_literal: true

# SociaVault API client for Facebook Marketplace searches
class APIClient
  class << self
    # Search Facebook Marketplace
    # @param query [String] Search keyword
    # @param lat [Float] Latitude
    # @param lng [Float] Longitude
    # @param min_price [Integer] Minimum price
    # @param max_price [Integer] Maximum price
    # @param radius_km [Integer] Search radius in kilometers
    # @param condition [String] Item condition (new, used_like_new, used_good, used_fair)
    # @param delivery_method [String] Delivery method (all, local_pickup, shipping)
    # @param count [Integer] Number of results to return
    # @return [Hash] API response containing listings
    def search(query:, lat:, lng:, min_price: nil, max_price: nil,
               radius_km: 65, condition: nil, delivery_method: nil, count: 24)
      params = build_params(
        query:,
        lat:,
        lng:,
        min_price:,
        max_price:,
        radius_km:,
        condition:,
        delivery_method:,
        count:
      )

      response = HTTParty.get(
        "#{BASE_URL}#{ENDPOINT}",
        query: params,
        headers: { 'X-API-Key' => Config.api_key },
        timeout: 30
      )

      handle_response(response)
    end

    # Build request parameters
    def build_params(query:, lat:, lng:, min_price: nil, max_price: nil,
                     radius_km: 65, condition: nil, delivery_method: nil, count: 24)
      params = {
        query:,
        lat:,
        lng:,
        radius_km:,
        count:,
        sort_by: 'creation_time_descend'
      }

      params[:min_price] = min_price if min_price
      params[:max_price] = max_price if max_price
      params[:condition] = condition if condition
      params[:delivery_method] = delivery_method if delivery_method

      params
    end

    # Handle API response
    def handle_response(response)
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
        raise "Server Error: #{response.parsed_response['error']}"
      else
        raise "API Error (#{response.code}): #{response.parsed_response['error'] || response.body}"
      end
    end

    BASE_URL = 'https://api.sociavault.com'
    ENDPOINT = '/v1/scrape/facebook-marketplace/search'
    private_constant :BASE_URL, :ENDPOINT
  end
end
