# frozen_string_literal: true

# == Schema Information
#
# Table name: geocode_cache_entries
#
#  id         :integer          not null, primary key
#  fetched_at :datetime         not null
#  kind       :string           not null
#  payload    :text             not null
#  query      :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_geocode_cache_entries_on_kind_and_query  (kind,query) UNIQUE
#
class GeocodeCacheEntry < ActiveRecord::Base
  KINDS = %w[search reverse].freeze

  validates :kind, inclusion: { in: KINDS }
  validates :query, presence: true
  validates :payload, presence: true
  validates :fetched_at, presence: true

  # Cached raw JSON for a successful lookup, or nil when there is no fresh
  # entry. Failures are deliberately not cached, so a transient Nominatim
  # outage does not make a city unreachable for a month.
  # @return [String, nil]
  def self.read(kind:, query:, ttl:)
    entry = find_by(kind: kind.to_s, query: query.to_s)
    return nil unless entry
    return nil if entry.fetched_at < ttl.ago

    entry.payload
  end

  # Store the raw JSON response. Repeated lookups of the same city (editing a
  # search, for example) then spend no Nominatim request at all.
  def self.write(kind:, query:, payload:)
    entry = find_or_initialize_by(kind: kind.to_s, query: query.to_s)
    entry.update!(payload: payload, fetched_at: Time.current)
  end
end
