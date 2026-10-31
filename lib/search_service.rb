# frozen_string_literal: true

# Runs a paged Marketplace search and returns only the listings worth keeping.
#
# Sits between the thin SociaVaultClient (one HTTP request per call) and the
# MarketplaceMonitor orchestrator. It owns the credit decisions:
#
#   * results are paged only while the current page still contains a title
#     match, because relevance ordering means later pages are filler;
#   * only listings whose title matches the query are returned, so unmatched
#     filler is never stored or alerted;
#   * listings are filtered by distance, sold status, and any future filters
#     in a composable pipeline (ListingFilter subclasses).
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
  # @param adapter [Class] ListingAdapter subclass (or module) for source normalization
  # @param filters [Array<ListingFilter>] filter pipeline; defaults to title, distance, sold
  def initialize(search_object:, client: SociaVaultClient, adapter: ListingAdapter, filters: nil)
    @search_object = search_object
    @client = client
    @adapter = adapter
    @matcher = ListingMatcher.new(query: @search_object.query)
    @filters = filters || default_filters
    @stats = { api_results: 0, pages_fetched: 0 }
  end

  # @yield called once per API request made (each one spends a credit)
  # @return [Array<ListingObject>] newest-first listings that pass all filters
  def run(&on_request)
    matches = []
    seen_ids = Set.new
    cursor = nil
    @stats = { api_results: 0, pages_fetched: 0, title_matches: 0 }

    # Setup phase: initialize each filter with search context.
    @filters.each { |f| f.before_search(@search_object) }

    MAX_PAGES.times do
      # Count the attempt before making it: a request that fails still spends
      # a credit.
      @stats[:pages_fetched] += 1
      page = @client.search_page(search_object: @search_object, cursor:, &on_request)
      listings = Array(page[:listings])
      @stats[:api_results] += listings.length
      break if listings.empty?

      page_matches = []
      listings.each do |listing|
        id = listing['id']
        next if id.nil? || seen_ids.include?(id)

        # Build ListingObject via the adapter (source-agnostic).
        listing_object = @adapter.from_socia_vault(listing, search_query: @search_object.query)

        # Title match is the fast gate: cheap string operation, no API call.
        # (ListingMatcher is the first filter in the pipeline.)
        next unless listing_object.title && @matcher.title_match?(title: listing['title'])

        seen_ids.add(id)
        @stats[:title_matches] += 1
        page_matches << listing_object
      end

      # Apply all filters in sequence (distance, sold, etc.).
      filtered = page_matches.select { |lo| @filters.all? { |f| f.filter(lo, @search_object) } }
      matches.concat(filtered)

      # Relevance ordering puts the real matches first. A page with no title
      # match means everything after it is filler, and each further page costs
      # a credit.
      break if page_matches.empty?

      cursor = page[:cursor]
      break if cursor.nil? || !page[:has_next_page]
    end

    # Teardown phase: collect per-filter stats.
    @filters.each { |f| f.after_search(@stats) }

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

  def default_filters
    [
      ListingDistanceFilter.new(radius_km: Distance.miles_to_km(@search_object.radius_mi)),
      ListingSoldFilter.new
    ]
  end
end
