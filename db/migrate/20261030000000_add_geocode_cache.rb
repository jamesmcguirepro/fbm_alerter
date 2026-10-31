# frozen_string_literal: true

# Replaces the old geocode_cache_entries table (kind + payload) with a new
# geocode_cache table optimized for forward geocode lookups.
#
# Migration strategy:
#   1. Create the new table with query, lat, lon, primary, fetched_at.
#   2. Backfill forward entries (kind = 'search'), expanding state abbreviations.
#   3. Drop the old table.
#
# Reverse geocode entries (kind = 'reverse') are not migrated — they were only
# used for SavedSearch#resolve_location! which runs once per search, so the
# Nominatim cost is negligible.
class AddGeocodeCache < ActiveRecord::Migration[8.1]
  # Standard USPS abbreviations — must match Geocoder::STATE_ABBREVS.
  STATE_ABBREVS = {
    'AL' => 'Alabama',   'AK' => 'Alaska',    'AZ' => 'Arizona',   'AR' => 'Arkansas',
    'CA' => 'California', 'CO' => 'Colorado',  'CT' => 'Connecticut', 'DE' => 'Delaware',
    'FL' => 'Florida',   'GA' => 'Georgia',   'HI' => 'Hawaii',    'ID' => 'Idaho',
    'IL' => 'Illinois',  'IN' => 'Indiana',   'IA' => 'Iowa',      'KS' => 'Kansas',
    'KY' => 'Kentucky',  'LA' => 'Louisiana', 'ME' => 'Maine',     'MD' => 'Maryland',
    'MA' => 'Massachusetts', 'MI' => 'Michigan', 'MN' => 'Minnesota', 'MS' => 'Mississippi',
    'MO' => 'Missouri',  'MT' => 'Montana',   'NE' => 'Nebraska',  'NV' => 'Nevada',
    'NH' => 'New Hampshire', 'NJ' => 'New Jersey', 'NM' => 'New Mexico', 'NY' => 'New York',
    'NC' => 'North Carolina', 'ND' => 'North Dakota', 'OH' => 'Ohio', 'OK' => 'Oklahoma',
    'OR' => 'Oregon',    'PA' => 'Pennsylvania', 'RI' => 'Rhode Island', 'SC' => 'South Carolina',
    'SD' => 'South Dakota', 'TN' => 'Tennessee', 'TX' => 'Texas',   'UT' => 'Utah',
    'VT' => 'Vermont',   'VA' => 'Virginia',  'WA' => 'Washington', 'WV' => 'West Virginia',
    'WI' => 'Wisconsin', 'WY' => 'Wyoming',   'DC' => 'District of Columbia'
  }.freeze

  def up
    create_table :geocode_cache, if_not_exists: true do |t|
      t.string :query, null: false
      t.decimal :lat, precision: 10, scale: 6
      t.decimal :lon, precision: 10, scale: 6
      t.boolean :primary, default: true, null: false
      t.datetime :fetched_at, null: false
      t.timestamps

      t.index [:query, :primary], unique: true
    end

    backfill_forward

    drop_table :geocode_cache_entries
  end

  def down
    create_table :geocode_cache_entries, if_not_exists: true do |t|
      t.string :kind, null: false
      t.string :query, null: false
      t.text :payload, null: false
      t.datetime :fetched_at, null: false
      t.timestamps

      t.index [:kind, :query], unique: true
    end

    # Forward entries: reconstruct approximate JSON payload from lat/lon.
    execute <<-SQL
      INSERT INTO geocode_cache_entries (kind, query, payload, fetched_at)
      SELECT 'search', query,
             '{"lat": ' || lat || ', "lon": ' || lon || '}'::text,
             fetched_at
      FROM geocode_cache
      WHERE primary = TRUE
    SQL

    drop_table :geocode_cache
  end

  private

  def backfill_forward
    entries = ActiveRecord::Base.connection.execute(
      "SELECT query, payload, fetched_at FROM geocode_cache_entries WHERE kind = 'search'"
    )

    entries.each do |row|
      next unless row['payload']

      begin
        data = JSON.parse(row['payload'])
        next unless data.is_a?(Hash) && data['lat'] && data['lon']
      rescue JSON::ParserError
        next
      end

      normalized = normalize_state(row['query'])
      ActiveRecord::Base.connection.execute(
        ActiveRecord::Base.sanitize_sql_for_assignment([
          "INSERT OR REPLACE INTO geocode_cache (query, lat, lon, primary, fetched_at, created_at, updated_at)
           VALUES (?, ?, ?, TRUE, ?, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)",
          normalized, data['lat'], data['lon'], row['fetched_at']
        ])
      )
    end
  end

  # Expand USPS state abbreviations in a city-state string.
  # "Austin, TX" → "Austin, Texas"
  def normalize_state(city_state)
    parts = city_state.strip.split(',').map(&:strip)
    city = parts[0]&.capitalize
    state = if parts[1] && STATE_ABBREVS[parts[1].upcase]
              STATE_ABBREVS[parts[1].upcase]
            else
              parts[1]&.capitalize
            end
    state ? "#{city}, #{state}" : city
  end
end
