# frozen_string_literal: true

# == Schema Information
#
# Table name: alerts
#
#  id         :integer          not null, primary key
#  sent_at    :datetime
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  listing_id :integer          not null
#  search_id  :integer          not null
#
# Indexes
#
#  index_alerts_on_listing_id  (listing_id)
#  index_alerts_on_search_id   (search_id)
#
# Foreign Keys
#
#  listing_id  (listing_id => listings.id)
#  search_id   (search_id => saved_searches.id)
#
class Alert < ActiveRecord::Base
  belongs_to :listing
  belongs_to :saved_search, foreign_key: :search_id

  # Record that +search_id+ was alerted about +listing_id+. Idempotent: a
  # (listing, search) pair is alerted at most once, so a repeat is a no-op.
  def self.record_alert(listing_id:, search_id:)
    create_or_find_by(listing_id:, search_id:) { |alert| alert.sent_at = Time.now }
  end
end
