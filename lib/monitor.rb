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

    SavedSearch.where(active: true).each do |saved_search|
      next if skip_invalid_coordinates?(saved_search)

      search_object = SearchObject.from_saved_search(saved_search:)

      new_listings = execute_search(search_object:, email: saved_search.email)

      send_alerts(listings: new_listings, saved_search:) if new_listings.any?
    end
  end

  def list_saved_searches
    SavedSearch.all.each { |search| search.print_search(io: @io) }
  end

  def remove_saved_search(id:)
    search = SavedSearch.find(id)

    search.print_search(io: @io)

    SavedSearch.delete(id)

    @io.puts "Deleted search ID #{search.id}"
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

    new_listings = execute_search(search_object:, email: saved_search.email)

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
  # @return [Array<Listing>] new listings found during this search
  def execute_search(search_object:, email: nil)
    @io.puts "\n  Searching: #{search_object.query} (#{search_object.lat}, #{search_object.long})"

    new_listings = []

    begin
      result = SociaVaultClient.search_from_object(search_object:)
      new_listings = handle_result(result:, search_query: search_object.query)
    rescue StandardError => e
      @io.puts "  ✗ Error: #{e.message}"
    end

    new_listings
  end

  def handle_result(result:, search_query:)
    new_listings = []
    if result['data'] && result['data']['listings'] && result['data']['listings'].any?
      listings = result['data']['listings'].values
      @io.puts "  Found #{listings.length} listing(s)"

      listings.each do |listing|
        listing_object = ListingObject.from_listing_response(response: listing, search_query: search_query)

        existing = Listing.exists?(listing_id: listing_object.listing_id)

        if existing
          @io.puts "Listing #{listing_object.title} already exists"
          # Still refresh last_seen_at without touching first_seen_at
          Listing.add_listing(listing_object:)
          next
        end

        new_listings << Listing.add_listing(listing_object:)
      end
    else
      @io.puts '  No listings found or unexpected response format'
    end

    new_listings
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
