# frozen_string_literal: true

# Runs a paged Marketplace search and returns only the listings worth keeping.
#
# Sits between the thin SociaVaultClient (one HTTP request per call) and the
# MarketplaceMonitor orchestrator. It owns the credit decisions:
#
#   * results are paged only while the current page still contains a title
#     match, because relevance ordering means later pages are filler;
#   * only listings whose title matches the query are returned, so unmatched
#     filler is never stored or alerted.
#
# No item/description lookups are made: each one would cost another credit.
class SearchService
  # Safety net on top of the title-match stop. The API team reported
  # has_next_page even for tiny result pools, so paging is bounded rather than
  # trusted.
  MAX_PAGES = 3

  # Raw listings returned by the API and API requests (credits) made, filled in
  # by #run. The alert email reports both.
  attr_reader :stats

  # @param search_object [SearchObject]
  # @param client [Class] thing that responds to search_page
  # @param matcher [ListingMatcher, nil]
  def initialize(search_object:, client: SociaVaultClient, matcher: nil)
    @search_object = search_object
    @client = client
    @matcher = matcher || ListingMatcher.new(query: search_object.query)
    @stats = { api_results: 0, pages_fetched: 0 }
  end

  # @yield called once per API request made (each one spends a credit)
  # @return [Array<ListingObject>] newest-first listings whose title matches
  def run(&on_request)
    matches = []
    seen_ids = Set.new
    cursor = nil
    @stats = { api_results: 0, pages_fetched: 0 }

    MAX_PAGES.times do
      # Count the attempt before making it: a request that fails still spends
      # a credit.
      @stats[:pages_fetched] += 1
      page = @client.search_page(search_object: @search_object, cursor:, &on_request)
      listings = Array(page[:listings])
      @stats[:api_results] += listings.length
      break if listings.empty?

      page_matches = listings.select { |listing| @matcher.title_match?(title: listing['title']) }
      page_matches.each do |listing|
        id = listing['id']
        next if id.nil? || seen_ids.include?(id)

        seen_ids.add(id)
        matches << ListingObject.from_listing_response(
          response: listing,
          search_query: @search_object.query
        )
      end

      # Relevance ordering puts the real matches first. A page with no title
      # match means everything after it is filler, and each further page costs
      # a credit.
      break if page_matches.empty?

      cursor = page[:cursor]
      break if cursor.nil? || !page[:has_next_page]
    end

    sort_newest_first(listings: matches)
  end

  private

  # Newest first, using each listing's own creation_time. The API's default
  # order is relevance-based -- which is what we want for matching -- so the
  # recency ordering is applied locally. Listings without a timestamp keep
  # their relative order at the end.
  def sort_newest_first(listings:)
    listings.each_with_index
            .sort_by { |listing, index| [-timestamp(listing:), index] }
            .map(&:first)
  end

  def timestamp(listing:)
    listing.listed_at ? listing.listed_at.to_f : -Float::INFINITY
  end
end
