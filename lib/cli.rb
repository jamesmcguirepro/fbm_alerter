# frozen_string_literal: true

class CLI < Thor
  desc 'add', 'Add a new search'
  option :query, aliases: ['-q'], required: true, desc: 'Search query'
  option :lat, required: true, desc: 'Latitude'
  option :long, required: true, desc: 'Longitude'
  option :radius, type: :numeric, desc: 'Radius (km)'
  option :min, type: :numeric, desc: 'Minimum price'
  option :max, type: :numeric, desc: 'Maximum price'
  option :cond, desc: 'Condition'
  option :del, desc: 'Delivery method'
  option :email, required: true, desc: 'Email address'
  def add
    puts "Adding item:"
    puts "  Query: #{options[:query]}"
    puts "  Location: #{options[:lat]}, #{options[:long]}"
    puts "  Price range: #{options[:min]} - #{options[:max]}"
    puts "  Condition: #{options[:cond]}"
    puts "  Delivery: #{options[:del]}"
    puts "  Email: #{options[:email]}"

    monitor.add_saved_search(search_object: search_object(options:), email: options[:email])
  end

  desc 'delete ID', 'Delete a saved search by ID'
  def delete(id)
    monitor.remove_saved_search(id:)
  end

  desc 'exec', 'Execute all saved searches'
  def exec
    puts "Executing saved searches"
    monitor.execute_saved_searches
  end

  desc 'list', 'List all items'
  def list
    puts "Listing all items..."
    monitor.list_saved_searches
  end

  desc 'search', 'Search for items'
  option :query, aliases: ['-q'], required: true, desc: 'Search query'
  option :lat, required: true, desc: 'Latitude'
  option :long, required: true, desc: 'Longitude'
  option :radius, type: :numeric, desc: 'Radius (km)'
  option :min, type: :numeric, desc: 'Minimum price'
  option :max, type: :numeric, desc: 'Maximum price'
  option :cond, desc: 'Condition'
  option :del, desc: 'Delivery method'
  def search
    puts "Searching for:"
    puts "  Query: #{options[:query]}"
    puts "  Location: #{options[:lat]}, #{options[:long]}"
    puts "  Radius: #{options[:radius]}"
    puts "  Price range: #{options[:min]} - #{options[:max]}"
    puts "  Condition: #{options[:cond]}"
    puts "  Delivery: #{options[:del]}"

    monitor.search(search_object: search_object(options:))
  end

  def self.exit_on_failure?
    true
  end

  private

  def monitor
    @_monitor ||= MarketplaceMonitor.new
  end

  def search_object(options: {})
    radius_km = options[:radius_km] || options[:radius]

    SearchObject.new(
      query: options[:query],
      lat: options[:lat],
      long: options[:long],
      min_price: options[:min],
      max_price: options[:max],
      radius_km: radius_km,
      condition: options[:cond],
      delivery_method: options[:del]
    )
  end
end
