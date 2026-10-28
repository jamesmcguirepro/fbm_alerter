# frozen_string_literal: true

# Turns the submitted search form into SavedSearch attributes. This is the one
# place that decides whether the coordinates came from the picker/manual fields
# or need a free-text city/ZIP lookup, so the web routes stay thin.
class SearchForm
  ATTRIBUTES = %i[
    query lat long min_price max_price radius_mi condition delivery_method
    email name resolved_location
  ].freeze

  attr_reader :attributes, :location_query

  def initialize(params)
    @params = params
    @location_query = param(:location_query).to_s.strip
    @attributes = ATTRIBUTES.to_h { |key| [key, param(key)] }
    resolve_location!
  end

  # Build a SavedSearch without saving it. `active:` is supplied by the edit
  # route, where the checkbox can pause the replacement search.
  def build(active: nil)
    search = SavedSearch.new(attributes)
    search.active = active unless active.nil?
    search
  end

  # Add the "couldn't find that place" explanation after validation has run.
  def add_location_error(record)
    error = location_error(record)
    record.errors.add(:base, error) if error
    record
  end

  private

  def param(key)
    value = @params[key]
    value.nil? ? @params[key.to_s] : value
  end

  # A picked candidate or manually entered coordinates already win; only an
  # unresolved free-text location needs a Nominatim lookup.
  def resolve_location!
    return if attributes[:lat].present? && attributes[:long].present?
    return if location_query.empty?

    place = Geocoder.search(query: location_query, limit: 1).first
    return unless place

    attributes[:lat] = place.lat
    attributes[:long] = place.long
    attributes[:resolved_location] = place.name
  end

  def location_error(record)
    return nil if record.lat.present? && record.long.present?
    return nil if location_query.empty?

    "We couldn't find #{location_query}. Pick a match from the list or enter coordinates manually."
  end
end
