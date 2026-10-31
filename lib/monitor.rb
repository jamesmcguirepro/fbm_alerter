# frozen_string_literal: true

# Main monitor orchestration
class MarketplaceMonitor
  def initialize(io: $stdout)
    @io = io
    Config.validate!
  end

  # @param [SearchObject] search_object
  # @param [String] email
  # @param [String, nil] resolved_location cached place name from a city lookup
  def add_saved_search(search_object:, email:, resolved_location: nil)
    SavedSearch.add_search(search_object:, email:, resolved_location:)
  rescue ActiveRecord::RecordInvalid => e
    @io.puts "✗ Could not add search: #{e.record.errors.full_messages.join(', ')}"
    nil
  end

  # Run a complete search cycle over all saved searches in the DB.
  # @param initiated_by [String] scheduler, gui or cli; recorded in monitor_runs
  def execute_saved_searches(initiated_by: 'cli')
    run = MonitorRun.start!(initiated_by:)
    @io.puts "\n🔍 Starting marketplace search at #{Time.now}..."

    SavedSearch.kept.where(active: true).each do |saved_search|
      next if skip_invalid_coordinates?(saved_search:)

      search_object = SearchObject.from_saved_search(saved_search:)

      result = execute_search(search_object:, email: saved_search.email, saved_search:)

      send_alerts(listings: result.listings, saved_search:, stats: result.stats) if result.listings.any?
    end

    capture_credit_snapshot(run)
    check_low_credit_alert
  ensure
    run&.finish!
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
    return [] if skip_invalid_coordinates?(saved_search:)

    search_object = SearchObject.from_saved_search(saved_search:)

    result = execute_search(search_object:, email: saved_search.email, saved_search:)

    send_alerts(listings: result.listings, saved_search:, stats: result.stats) if result.listings.any?

    result.listings
  end

  private

  # Skip saved searches whose coordinates are missing or out of range rather
  # than calling the API with a bad location. Returns true when skipped.
  def skip_invalid_coordinates?(saved_search:)
    return false if saved_search.valid_coordinates?

    @io.puts "  ⚠ Skipping '#{saved_search.query}' (ID #{saved_search.id}): " \
             "invalid coordinates (#{saved_search.lat}, #{saved_search.long})"
    true
  end

  # Monitor a single search query
  # @param [SearchObject] search_object
  # @param [String] email
  # @param [SavedSearch] saved_search the search this run belongs to, when known
  # @return [SearchResult] new listings plus the API counts for this search
  def execute_search(search_object:, email: nil, saved_search: nil)
    @io.puts "\n  Searching: #{search_object.query} (#{search_object.lat}, #{search_object.long})"

    # Dry run: skip the API call entirely, and record no run, because no
    # credit was actually spent.
    if Config.dry_run?
      @io.puts '  ⃠ DRY RUN — API call skipped, no credit spent'
      return SearchResult.empty
    end

    # One SearchRun per API request (each page spends a credit), with the first
    # successful run recorded as the discovery run for the listings it returns.
    discovery_run = nil
    service = SearchService.new(search_object:)
    listings = service.run do
      next unless saved_search

      run = SearchRun.record(saved_search:)
      discovery_run ||= run
    end

    new_listings = handle_listings(listings:, search_run: discovery_run, saved_search:)

    matcher = ListingMatcher.new(query: search_object.query)
    exact_matches = new_listings.count { |listing| matcher.exact_match?(title: listing.title) }

    SearchResult.build(
      listings: new_listings,
      api_results: service.stats[:api_results],
      credits_used: service.stats[:pages_fetched],
      exact_matches:,
      stats: service.stats
    )
  rescue StandardError => e
    @io.puts "  ✗ Error: #{e.message}"
    # The attempt still spent a credit.
    SearchRun.record(saved_search:, success: false) if saved_search
    SearchResult.empty
  end

  # Store confirmed title matches and return the ones this search has not
  # alerted about yet.
  # @param listings [Array<ListingObject>]
  def handle_listings(listings:, search_run: nil, saved_search: nil)
    new_listings = []

    if listings.any?
      @io.puts "  Found #{listings.length} matching listing(s)"

      listings.each do |listing_object|
        # add_listing upserts, so a listing is stored once globally (by its
        # Facebook id) no matter which search saw it first.
        saved = Listing.add_listing(listing_object:, search_run:)

        if new_for_search?(listing: saved, saved_search:)
          new_listings << saved
        elsif saved_search
          @io.puts "Listing #{saved.title} already alerted for this search"
        else
          @io.puts "Listing #{saved.title} already exists"
        end
      end
    else
      @io.puts '  No title-matching listings found'
    end

    new_listings
  end

  # Whether this search still needs to be alerted about a listing. Dedup is per
  # saved search: the same listing can alert each search that matches it, but
  # only once. Without a saved search (ad-hoc CLI run) there is nothing to
  # dedup against, so fall back to first-ever sighting.
  def new_for_search?(listing:, saved_search:)
    return listing.previously_new_record? if saved_search.nil?

    !Alert.exists?(listing_id: listing.id, search_id: saved_search.id)
  end

  # Send alerts for new listings
  def send_alerts(listings:, saved_search:, stats: {})
    if listings.any?
      @io.puts "\n📧 Sending alerts for #{listings.length} new listing(s)..."
      EmailService.send_alerts(
        listings:,
        emails: [saved_search.email],
        query: saved_search.query,
        stats:,
        exact_count: stats[:exact_matches],
        search_url: saved_search.marketplace_url,
        location_label: saved_search.location_label,
        price_range: saved_search.price_range_text,
        radius_mi: saved_search.radius_mi
      )
      listings.each { |listing| Alert.record_alert(listing_id: listing.id, search_id: saved_search.id) }
    else
      @io.puts "\n✓ No new listings to alert"
    end
  end

  # Record the current credit balance and purge old snapshots.
  def capture_credit_snapshot(run)
    return if Config.dry_run?

    snapshot = CreditSnapshot.capture(monitor_run: run)
    return if snapshot.nil?

    @io.puts "\n💾 Credits recorded — balance: #{snapshot.balance}"
    CreditSnapshot.purge_old!
  end

  # Send a low-credit alert when the projected balance runs out soon.
  # At most one alert per day.
  def check_low_credit_alert
    return if Config.dry_run?

    unless credit_alert_needed?
      @io.puts "\n✓ Credit alert: no action needed"
      return
    end

    @io.puts "\n⚠ Low credits — sending alert"
    EmailService.send_low_credit_alert

    # Record that we sent an alert today so we don't spam.
    AlertRecord.set_low_credit_alerted(type: AlertRecord::LOW_CREDIT)
  end

  # Whether a low-credit alert should be sent.
  # Returns true when:
  #   - We have at least 2 snapshots to establish a trend
  #   - Projected days until exhaustion < 7
  #   - We haven't alerted today yet
  def credit_alert_needed?
    return false unless CreditSnapshot.recent.count >= 2
    return false if AlertRecord.low_credit_alerted_today?

    days_remaining = CreditSnapshot.days_remaining
    return true if days_remaining.nil? || days_remaining < 7

    false
  end
end
