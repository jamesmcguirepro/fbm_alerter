#!/usr/bin/env ruby

require 'bundler/setup' if File.exist?('Gemfile.lock')
require 'httparty'
require 'json'
require 'sqlite3'
require 'mail'
require 'dotenv/load'
require 'chronic_duration'
require 'whenever'

# Load environment variables
ENV.update(dotenv_default_path: '.env')

# ==================== Configuration ====================
class Config
  def self.api_key
    ENV['SOCIAVAULT_API_KEY'] || raise('SOCIAVAULT_API_KEY not set in .env')
  end

  def self.email_from
    ENV['EMAIL_FROM'] || 'marketplace-alerts@example.com'
  end

  def self.email_to
    (ENV['EMAIL_TO'] || '').split(',').map(&:strip)
  end

  def self.smtp_address
    ENV['SMTP_ADDRESS'] || 'smtp.gmail.com'
  end

  def self.smtp_port
    ENV['SMTP_PORT'] || 587
  end

  def self.smtp_username
    ENV['SMTP_USERNAME']
  end

  def self.smtp_password
    ENV['SMTP_PASSWORD']
  end

  def self.db_path
    ENV['DB_PATH'] || './marketplace_monitor.db'
  end

  def self.search_config
    # Parse searches from ENV, e.g., SEARCHES="bike|30.2677|-97.7475|100|500; mountain bike|40.7128|-74.0060|50|300"
    raw = ENV['SEARCHES'] || raise('SEARCHES not set in .env')
    raw.split(';').map do |search|
      parts = search.strip.split('|')
      {
        query: parts[0].strip,
        lat: parts[1].to_f,
        lng: parts[2].to_f,
        min_price: parts[3].to_i,
        max_price: parts[4].to_i,
        radius_km: (parts[5] || 65).to_i,
        radius_km: (parts[5] || 65).to_i,
        condition: parts[6]&.strip,
        delivery_method: parts[7]&.strip
      }
    end
  end
end

# ==================== Database Setup ====================
class Database
  def self.connect
    SQLite3.new Config.db_path
  end

  def self.initialize_db
    db = connect
    db.execute <<-SQL
      CREATE TABLE IF NOT EXISTS listings (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        price REAL,
        location TEXT,
        url TEXT,
        image_url TEXT,
        search_query TEXT,
        first_seen_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        last_seen_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        is_sold BOOLEAN DEFAULT 0
      );
    SQL
    db.execute <<-SQL
      CREATE TABLE IF NOT EXISTS alerts_sent (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        listing_id TEXT NOT NULL,
        sent_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY(listing_id) REFERENCES listings(id)
      );
    SQL
    db.close
  end

  def self.add_listing(listing_data, search_query)
    db = connect
    db.execute <<-SQL, [
      listing_data['id'],
      listing_data['title'],
      listing_data['price']['amount'],
      listing_data['location']['display_name'],
      listing_data['url'],
      listing_data['primary_photo']&.dig('url'),
      search_query,
      Time.now
    ]
      INSERT OR IGNORE INTO listings 
      (id, title, price, location, url, image_url, search_query, last_seen_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    SQL

    db.execute "UPDATE listings SET last_seen_at = ? WHERE id = ?", [Time.now, listing_data['id']]
    db.close
  end

  def self.get_unseen_listings
    db = connect
    db.results_as_hash = true
    listings = db.execute <<-SQL
      SELECT l.* FROM listings l
      LEFT JOIN alerts_sent a ON l.id = a.listing_id
      WHERE a.id IS NULL AND l.is_sold = 0
      ORDER BY l.first_seen_at DESC;
    SQL
    db.close
    listings
  end

  def self.mark_alert_sent(listing_id)
    db = connect
    db.execute "INSERT INTO alerts_sent (listing_id) VALUES (?)", [listing_id]
    db.close
  end

  def self.mark_sold(listing_id)
    db = connect
    db.execute "UPDATE listings SET is_sold = 1 WHERE id = ?", [listing_id]
    db.close
  end
end

# ==================== API Client ====================
class MarketplaceAPI
  BASE_URL = 'https://api.sociavault.com'

  def self.search(query:, lat:, lng:, min_price: nil, max_price: nil, radius_km: 65, condition: nil, delivery_method: nil, count: 24)
    params = {
      query: query,
      lat: lat,
      lng: lng,
      radius_km: radius_km,
      count: count,
      sort_by: 'creation_time_descend'
    }

    params[:min_price] = min_price if min_price
    params[:max_price] = max_price if max_price
    params[:condition] = condition if condition
    params[:delivery_method] = delivery_method if delivery_method

    response = HTTParty.get(
      "#{BASE_URL}/v1/scrape/facebook-marketplace/search",
      query: params,
      headers: { 'X-API-Key' => Config.api_key },
      timeout: 30
    )

    unless response.success?
      raise "API Error (#{response.code}): #{response.parsed_response['error'] || response.body}"
    end

    response.parsed_response
  end
end

# ==================== Email Service ====================
class EmailService
  def self.configure_smtp
    Mail.defaults do
      delivery_method :smtp, {
        address: Config.smtp_address,
        port: Config.smtp_port,
        user_name: Config.smtp_username,
        password: Config.smtp_password,
        authentication: 'plain',
        enable_starttls_auto: true
      }
    end
  end

  def self.send_alerts(listings)
    return if listings.empty?

    configure_smtp

    subject = "🔔 #{listings.length} New Marketplace Listing(s)"
    html_body = build_html_email(listings)

    Config.email_to.each do |recipient|
      begin
        mail = Mail.new do
          from Config.email_from
          to recipient
          subject subject
          html_part do
            content_type 'text/html; charset=UTF-8'
            body html_body
          end
        end
        mail.deliver!
        puts "✓ Email sent to #{recipient}"
      rescue => e
        puts "✗ Failed to send email to #{recipient}: #{e.message}"
      end
    end
  end

  private

  def self.build_html_email(listings)
    html = <<~HTML
      <html>
        <head>
          <style>
            body { font-family: Arial, sans-serif; background: #f5f5f5; }
            .container { max-width: 800px; margin: 20px auto; background: white; padding: 20px; border-radius: 8px; }
            .header { color: #333; border-bottom: 2px solid #007bff; padding-bottom: 10px; }
            .listing { border: 1px solid #ddd; margin: 15px 0; padding: 15px; border-radius: 4px; }
            .listing:hover { background: #f9f9f9; }
            .title { font-size: 18px; font-weight: bold; color: #007bff; margin: 10px 0; }
            .price { font-size: 24px; font-weight: bold; color: #28a745; }
            .location { color: #666; font-size: 14px; }
            .image { max-width: 100%; height: auto; margin: 10px 0; border-radius: 4px; }
            .link { display: inline-block; margin-top: 10px; padding: 8px 16px; background: #007bff; color: white; text-decoration: none; border-radius: 4px; }
            .link:hover { background: #0056b3; }
            .query { background: #f0f0f0; padding: 5px 10px; border-radius: 3px; font-size: 12px; color: #666; display: inline-block; margin: 5px 0; }
          </style>
        </head>
        <body>
          <div class="container">
            <div class="header">
              <h1>🔔 New Marketplace Listings</h1>
              <p>Found #{listings.length} new listing(s) matching your searches</p>
            </div>
    HTML

    listings.each do |listing|
      image_html = listing['image_url'] ? %(<img src="#{listing['image_url']}" class="image" />) : ''
      html += <<~HTML
        <div class="listing">
          <span class="query">#{listing['search_query']}</span>
          #{image_html}
          <div class="title">#{listing['title']}</div>
          <div class="price">$#{listing['price']&.round(2) || 'N/A'}</div>
          <div class="location">📍 #{listing['location']}</div>
          <a href="#{listing['url']}" class="link" target="_blank">View Listing</a>
          <div style="font-size: 12px; color: #999; margin-top: 10px;">
            Listed: #{listing['first_seen_at']}
          </div>
        </div>
      HTML
    end

    html += <<~HTML
        <div style="text-align: center; margin-top: 30px; padding-top: 20px; border-top: 1px solid #ddd; color: #666; font-size: 12px;">
          <p>Marketplace Monitor • Automated Email Alert</p>
        </div>
      </div>
    </body>
  </html>
    HTML

    html
  end
end

# ==================== Main Monitor ====================
class MarketplaceMonitor
  def run_search
    puts "\n🔍 Starting marketplace search at #{Time.now}..."

    Config.search_config.each do |search|
      monitor_search(search)
    end

    # Send any unseen listings
    unseen = Database.get_unseen_listings
    if unseen.any?
      puts "📧 Sending alerts for #{unseen.length} new listing(s)..."
      EmailService.send_alerts(unseen)
      unseen.each { |listing| Database.mark_alert_sent(listing['id']) }
    else
      puts "✓ No new listings to alert"
    end
  end

  private

  def monitor_search(search)
    puts "\n  Searching: #{search[:query]} (#{search[:lat]}, #{search[:lng]})"

    begin
      result = MarketplaceAPI.search(**search)

      if result['data'] && result['data']['listings']
        listings = result['data']['listings'].values

        puts "  Found #{listings.length} listing(s)"

        listings.each do |listing|
          Database.add_listing(listing, search[:query])
        end
      else
        puts "  No listings found or unexpected response format"
      end

    rescue => e
      puts "  ✗ Error: #{e.message}"
    end
  end
end

# ==================== CLI & Scheduling ====================
if __FILE__ == $0
  case ARGV[0]
  when 'init'
    puts "Initializing database..."
    Database.initialize_db
    puts "✓ Database initialized at #{Config.db_path}"

  when 'run'
    puts "Running marketplace monitor once..."
    Database.initialize_db
    MarketplaceMonitor.new.run_search

  when 'schedule'
    puts "Setting up cron schedule..."
    schedule_interval = ENV['SCHEDULE_INTERVAL'] || '30m'
    puts "Monitor will run every #{schedule_interval}"
    puts "Configure SCHEDULE_INTERVAL in .env to change frequency"

  when 'daemon'
    # Run continuously with interval
    Database.initialize_db
    monitor = MarketplaceMonitor.new
    interval = ChronicDuration.parse(ENV['SCHEDULE_INTERVAL'] || '30m')

    puts "Starting marketplace monitor daemon (interval: #{interval}s)..."
    loop do
      begin
        monitor.run_search
      rescue => e
        puts "✗ Daemon error: #{e.message}"
        puts e.backtrace.first(5)
      end
      puts "Sleeping for #{interval}s until next run...\n"
      sleep(interval)
    end

  else
    puts <<~USAGE
      Marketplace Monitor - Facebook Marketplace Alert System

      Commands:
        init       Initialize the database
        run        Run search once and send alerts
        daemon     Run continuously with scheduled intervals
        schedule   Show cron scheduling instructions

      Configuration (.env):
        SOCIAVAULT_API_KEY=sk_live_xxxxx
        EMAIL_FROM=alerts@example.com
        EMAIL_TO=user@example.com,another@example.com
        SMTP_ADDRESS=smtp.gmail.com
        SMTP_PORT=587
        SMTP_USERNAME=your_email@gmail.com
        SMTP_PASSWORD=your_app_password
        DB_PATH=./marketplace_monitor.db
        SCHEDULE_INTERVAL=30m  (used for daemon mode)
        SEARCHES=bike|30.2677|-97.7475|100|500;mountain bike|40.7128|-74.0060|50|300

      Usage Examples:
        ruby marketplace_monitor.rb init
        ruby marketplace_monitor.rb run
        ruby marketplace_monitor.rb daemon          # Ctrl+C to stop

      For cron scheduling (e.g., every 30 minutes):
        */30 * * * * cd /path/to/app && ruby marketplace_monitor.rb run
    USAGE
  end
end
