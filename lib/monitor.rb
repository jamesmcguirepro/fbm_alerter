# frozen_string_literal: true

# Main monitor orchestration
class MarketplaceMonitor
  def initialize(io: $stdout)
    @io = io
    Config.validate!
  end

  # @param [SearchObject] search_object
  # @param [String] email
  def add_saved_search(search_object:, email:)
    SavedSearch.add_search(search_object:, email:)
  rescue ActiveRecord::RecordInvalid => e
    @io.puts "✗ Could not add search: #{e.record.errors.full_messages.join(', ')}"
    nil
  end

  # Run a complete search cycle over all saved searches in the DB
  def execute_saved_searches
    @io.puts "\n🔍 Starting marketplace search at #{Time.now}..."

    SavedSearch.kept.where(active: true).each do |saved_search|
      next if skip_invalid_coordinates?(saved_search)

      search_object = SearchObject.from_saved_search(saved_search:)

      new_listings = execute_search(search_object:, email: saved_search.email, saved_search:)

      send_alerts(listings: new_listings, saved_search:) if new_listings.any?
    end
  end

  def list_saved_searches
    SavedSearch.kept.each { |search| search.print_search(io: @io) }
  end

  def remove_saved_search(id:)
    search = SavedSearch.find(id)

    search.print_search(io: @io)

    # Soft delete: the search disappears, its alert and run history does not.
    search.discard

    @io.puts "Deleted search ID #{search.id} (its alerts and run history are kept)"
  end

  # @param [SearchObject] search_object
  def search(search_object:)
    execute_search(search_object:)
  end

  # Run a single saved search by ID and return new listings
  # @param [Integer] id
  # @return [Array<Listing>]
  def run_single(id:)
    saved_search = SavedSearch.find(id)
    return [] if skip_invalid_coordinates?(saved_search)

    search_object = SearchObject.from_saved_search(saved_search:)

    new_listings = execute_search(search_object:, email: saved_search.email, saved_search:)

    send_alerts(listings: new_listings, saved_search:) if new_listings.any?

    new_listings
  end

  private

  # Skip saved searches whose coordinates are missing or out of range rather
  # than calling the API with a bad location. Returns true when skipped.
  def skip_invalid_coordinates?(saved_search)
    return false if saved_search.valid_coordinates?

    @io.puts "  ⚠ Skipping '#{saved_search.query}' (ID #{saved_search.id}): " \
             "invalid coordinates (#{saved_search.lat}, #{saved_search.long})"
    true
  end

  # Monitor a single search query
  # @param [SearchObject] search_object
  # @param [String] email
  # @param [SavedSearch] saved_search the search this run belongs to, when known
  # @return [Array<Listing>] new listings found during this search
  def execute_search(search_object:, email: nil, saved_search: nil)
    @io.puts "\n  Searching: #{search_object.query} (#{search_object.lat}, #{search_object.long})"

    # Dry run: skip the API call entirely, and record no run, because no
    # credit was actually spent.
    if Config.dry_run?
      @io.puts '  ⃠ DRY RUN — API call skipped, no credit spent'
      return []
    end

    fetched = api_search(search_object:, saved_search:)
    return [] if fetched.nil?

    result, discovery_run = fetched
    handle_result(result:, search_query: search_object.query,
                  search_run: discovery_run, saved_search:)
  rescue StandardError => e
    @io.puts "  ✗ Error: #{e.message}"
    []
  end

  # Run the (possibly paged) search, recording one SearchRun per API request —
  # each request spends a credit. Returns [response, discovery_run], or nil if
  # the search failed, having first recorded the failed request.
  def api_search(search_object:, saved_search:)
    runs = []
    result = SociaVaultClient.search_from_object(search_object:) do
      runs << SearchRun.record(saved_search:) if saved_search
    end

    [result, runs.first]
  rescue StandardError => e
    @io.puts "  ✗ Error: #{e.message}"
    # The attempt still spent a credit.
    SearchRun.record(saved_search:, success: false) if saved_search
    nil
  end

  def handle_result(result:, search_query:, search_run: nil, saved_search: nil)
    new_listings = []
    if result['data'] && result['data']['listings'] && result['data']['listings'].any?
      listings = result['data']['listings'].values
      @io.puts "  Found #{listings.length} listing(s)"

      listings.each do |listing|
        listing_object = ListingObject.from_listing_response(response: listing, search_query: search_query)

        # add_listing upserts, so a listing is stored once globally (by its
        # Facebook id) no matter which search saw it first.
        saved = Listing.add_listing(listing_object:, search_run:)

        if new_for_search?(saved, saved_search)
          new_listings << saved
        elsif saved_search
          @io.puts "Listing #{saved.title} already alerted for this search"
        else
          @io.puts "Listing #{saved.title} already exists"
        end
      end
    else
      @io.puts '  No listings found or unexpected response format'
    end

    new_listings
  end

  # Whether this search still needs to be alerted about a listing. Dedup is per
  # saved search: the same listing can alert each search that matches it, but
  # only once. Without a saved search (ad-hoc CLI run) there is nothing to
  # dedup against, so fall back to first-ever sighting.
  def new_for_search?(listing, saved_search)
    return listing.previously_new_record? if saved_search.nil?

    !Alert.exists?(listing_id: listing.id, search_id: saved_search.id)
  end

  # Send alerts for new listings
  def send_alerts(listings:, saved_search:)
    if listings.any?
      @io.puts "\n📧 Sending alerts for #{listings.length} new listing(s)..."
      EmailService.send_alerts(listings:, emails: [saved_search.email], query: saved_search.query)
      listings.each { |listing| Alert.record_alert(listing_id: listing.id, search_id: saved_search.id) }
    else
      @io.puts "\n✓ No new listings to alert"
    end
  end
end
