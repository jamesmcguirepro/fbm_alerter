# frozen_string_literal: true

# Main monitor orchestration
class Monitor
  def initialize
    Config.validate!
  end

  # Run a complete search cycle
  def run_search
    puts "\n🔍 Starting marketplace search at #{Time.now}..."

    Config.search_config.each do |search|
      monitor_search(search)
    end

    # Send alerts for unseen listings
    send_alerts
  end

  private

  # Monitor a single search query
  def monitor_search(search)
    puts "\n  Searching: #{search[:query]} (#{search[:lat]}, #{search[:long]})"

    begin
      result = SociaVaultClient.search(**search)

      if result['data'] && result['data']['listings'] && result['data']['listings'].any?
        listings = result['data']['listings'].values
        puts "  Found #{listings.length} listing(s)"

        listings.each do |listing|
          Listing.add_listing(listing, search[:query])
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
