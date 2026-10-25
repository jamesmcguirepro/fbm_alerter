# frozen_string_literal: true

# The outcome of one search: the listings worth alerting on, plus the numbers
# the alert email reports about the API calls that produced them.
class SearchResult < Data.define(:listings, :api_results, :filtered, :credits_used, :exact_matches)
  # @param listings [Array<Listing>] listings new to this search
  # @param api_results [Integer] raw listings returned across every page fetched
  # @param credits_used [Integer] API requests made (one credit each)
  # @param exact_matches [Integer] new listings whose title contains every query keyword
  def self.build(listings:, api_results:, credits_used:, exact_matches: 0)
    new(
      listings:,
      api_results:,
      filtered: [api_results - listings.length, 0].max,
      credits_used:,
      exact_matches:
    )
  end

  def self.empty
    new(listings: [], api_results: 0, filtered: 0, credits_used: 0, exact_matches: 0)
  end

  # Stats without the listings, ready to hand to EmailService.
  # @return [Hash]
  def stats
    { api_results:, filtered:, credits_used:, exact_matches: }
  end
end
