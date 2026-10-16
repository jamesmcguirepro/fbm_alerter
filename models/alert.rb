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
  has_one :listing
  has_one :saved_search, foreign_key: :search_id

  def self.record_alert(listing_id:, search_id:)
    self.create!(listing_id:, search_id:, sent_at: Time.now)
  end
end
