# frozen_string_literal: true

module MarketplaceMonitor
  # SQLite database operations and management
  class Database
    class << self
      def connect
        SQLite3.new Config.db_path
      end

      # Initialize database schema
      def initialize_db
        db = connect
        db.execute <<~SQL
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

        db.execute <<~SQL
          CREATE TABLE IF NOT EXISTS alerts_sent (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            listing_id TEXT NOT NULL,
            sent_at DATETIME DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY(listing_id) REFERENCES listings(id)
          );
        SQL

        db.close
      end

      # Add or update a listing in the database
      def add_listing(listing_data, search_query)
        db = connect

        # Insert or ignore (skip if already exists)
        db.execute <<~SQL, [
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

        # Update last_seen_at for existing listings
        db.execute "UPDATE listings SET last_seen_at = ? WHERE id = ?", [Time.now, listing_data['id']]

        db.close
      end

      # Get all listings that haven't been alerted yet
      def get_unseen_listings
        db = connect
        db.results_as_hash = true

        listings = db.execute <<~SQL
          SELECT l.* FROM listings l
          LEFT JOIN alerts_sent a ON l.id = a.listing_id
          WHERE a.id IS NULL AND l.is_sold = 0
          ORDER BY l.first_seen_at DESC;
        SQL

        db.close
        listings
      end

      # Mark a listing as alerted
      def mark_alert_sent(listing_id)
        db = connect
        db.execute "INSERT INTO alerts_sent (listing_id) VALUES (?)", [listing_id]
        db.close
      end

      # Mark a listing as sold
      def mark_sold(listing_id)
        db = connect
        db.execute "UPDATE listings SET is_sold = 1 WHERE id = ?", [listing_id]
        db.close
      end

      # Get database statistics
      def statistics
        db = connect
        db.results_as_hash = true

        stats = {
          total_listings: db.execute("SELECT COUNT(*) as count FROM listings")[0]['count'],
          listings_by_search: db.execute(
            "SELECT search_query, COUNT(*) as count FROM listings GROUP BY search_query"
          ),
          total_alerts_sent: db.execute("SELECT COUNT(*) as count FROM alerts_sent")[0]['count'],
          sold_listings: db.execute("SELECT COUNT(*) as count FROM listings WHERE is_sold = 1")[0]['count']
        }

        db.close
        stats
      end

      # Clear old listings (older than specified days)
      def cleanup_old_listings(days = 30)
        db = connect
        cutoff_date = (Time.now - (days * 86400)).to_s

        result = db.execute(
          "DELETE FROM listings WHERE first_seen_at < ?",
          [cutoff_date]
        )

        deleted = db.changes
        db.close

        deleted
      end

      # Export listings to JSON
      def export_to_json(filename = 'listings_export.json')
        db = connect
        db.results_as_hash = true

        listings = db.execute("SELECT * FROM listings ORDER BY first_seen_at DESC")

        File.write(filename, JSON.pretty_generate(listings))
        db.close

        filename
      end
    end
  end
end
