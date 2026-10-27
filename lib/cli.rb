# frozen_string_literal: true

class CLI < Thor
  desc 'add', 'Add a new search'
  option :query, aliases: ['-q'], required: true, desc: 'Search query'
  option :city, desc: 'City, state or ZIP (resolved to coordinates)'
  option :lat, desc: 'Latitude (alternative to --city)'
  option :long, desc: 'Longitude (alternative to --city)'
  option :radius, type: :numeric, default: 40, desc: 'Radius (miles)'
  option :min, type: :numeric, desc: 'Minimum price'
  option :max, type: :numeric, desc: 'Maximum price'
  option :cond, desc: 'Condition'
  option :del, desc: 'Delivery method'
  option :email, required: true, desc: 'Email address'
  def add
    puts "Adding item:"
    location = resolve_location(options)

    puts "  Query: #{options[:query]}"
    puts "  Location: #{location_label(location)}"
    puts "  Radius: #{options[:radius]} mi"
    puts "  Price range: #{options[:min]} - #{options[:max]}"
    puts "  Condition: #{options[:cond]}"
    puts "  Delivery: #{options[:del]}"
    puts "  Email: #{options[:email]}"

    monitor.add_saved_search(
      search_object: search_object(options:, location:),
      email: options[:email],
      resolved_location: location[:resolved_location]
    )
  end

  desc 'delete ID', 'Delete a saved search by ID'
  def delete(id)
    monitor.remove_saved_search(id:)
  end

  desc 'exec', 'Execute all saved searches'
  def exec
    puts "Executing saved searches"
    monitor.execute_saved_searches(initiated_by: 'cli')
  end

  desc 'schedule', 'Run all saved searches daily at SCHEDULE_AT'
  def schedule
    Scheduler.new.run
  end

  desc 'list', 'List all items'
  def list
    puts "Listing all items..."
    monitor.list_saved_searches
  end

  desc 'search', 'Search for items'
  option :query, aliases: ['-q'], required: true, desc: 'Search query'
  option :city, desc: 'City, state or ZIP (resolved to coordinates)'
  option :lat, desc: 'Latitude (alternative to --city)'
  option :long, desc: 'Longitude (alternative to --city)'
  option :radius, type: :numeric, default: 40, desc: 'Radius (miles)'
  option :min, type: :numeric, desc: 'Minimum price'
  option :max, type: :numeric, desc: 'Maximum price'
  option :cond, desc: 'Condition'
  option :del, desc: 'Delivery method'
  def search
    puts "Searching for:"
    location = resolve_location(options)

    puts "  Query: #{options[:query]}"
    puts "  Location: #{location_label(location)}"
    puts "  Radius: #{options[:radius]} mi"
    puts "  Price range: #{options[:min]} - #{options[:max]}"
    puts "  Condition: #{options[:cond]}"
    puts "  Delivery: #{options[:del]}"

    monitor.search(search_object: search_object(options:, location:))
  end

  def self.exit_on_failure?
    true
  end

  private

  def monitor
    @_monitor ||= MarketplaceMonitor.new
  end

  # Either resolve --city through Nominatim, or use the supplied coordinates.
  # Keeping both paths here means add/search share the same validation.
  def resolve_location(options)
    city = options[:city].to_s.strip
    has_coordinates = options[:lat].present? && options[:long].present?

    if city.present? && has_coordinates
      raise Thor::Error, 'Provide --city or --lat/--long, not both'
    end

    if has_coordinates
      return { lat: options[:lat], long: options[:long], resolved_location: nil }
    end

    if city.empty?
      raise Thor::Error, 'Provide --city, or both --lat and --long'
    end

    puts "  Looking up #{city}..."
    place = Geocoder.search(query: city, limit: 1).first
    raise Thor::Error, "Could not find location #{city.inspect}" unless place

    { lat: place.lat, long: place.long, resolved_location: place.name }
  end

  def location_label(location)
    coordinates = "#{location[:lat]}, #{location[:long]}"
    location[:resolved_location] ? "#{location[:resolved_location]} (#{coordinates})" : coordinates
  end

  def search_object(options: {}, location:)
    SearchObject.new(
      id: nil,
      query: options[:query],
      lat: location[:lat],
      long: location[:long],
      min_price: options[:min],
      max_price: options[:max],
      radius_mi: options[:radius],
      condition: options[:cond],
      delivery_method: options[:del]
    )
  end
end
