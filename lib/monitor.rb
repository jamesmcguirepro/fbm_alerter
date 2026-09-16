# frozen_string_literal: true

# Main monitor orchestration
class Monitor
  def initialize
    Config.validate!
  end

  # @param [SearchObject] search_object
  # @param [String] email
  def add_saved_search(search_object:, email:)
    SavedSearch.add_search(search_object:, email:)
  end

  # Run a complete search cycle
  def execute_saved_searches
    puts "\n🔍 Starting marketplace search at #{Time.now}..."

    SavedSearch.all.each do |saved_search|

      execute_search(search)
    end

    # Send alerts for unseen listings
    send_alerts
  end

  def list_saved_searches
    SavedSearch.all.each(&:print_search)
  end

  def remove_saved_search(id:)
    search = SavedSearch.find(id)

    search.print_search

    SavedSearch.delete(id)

    puts "Deleted search ID #{search.id}"
  end

  def search(query)
    execute_search(query)
  end

  private

  # Monitor a single search query
  # @param [SearchObject] search_object
  # @param [String] email
  def execute_search(search_object:, email:)
    puts "\n  Searching: #{search_object.query} (#{search_object.lat}, #{search_object.long})"

    begin
      result = SociaVaultClient.search(**search_object.search_hash)

      if result['data'] && result['data']['listings'] && result['data']['listings'].any?
        listings = result['data']['listings'].values
        puts "  Found #{listings.length} listing(s)"

        listings.each do |listing|
          Listing.add_listing(listing, search_object.query)
        end
      else
        puts '  No listings found or unexpected response format'
      end
    rescue StandardError => e
      puts "  ✗ Error: #{e.message}"
    end
  end

  # Send alerts for new listings
  def send_alerts
    unseen_listings = Listing.unnotified_and_unsold

    if unseen_listings.any?
      puts "\n📧 Sending alerts for #{unseen_listings.length} new listing(s)..."
      EmailService.send_alerts(unseen_listings)
      unseen_listings.each { |listing| Alert.record_alert(listing_id: listing['id']) }
    else
      puts "\n✓ No new listings to alert"
    end
  end
end
