# == Schema Information
#
# Table name: alerts
#
#  id         :integer          not null, primary key
#  listing_id :integer
#  search_id  :integer
#  sent_at    :datetime
#
class Alert < ActiveRecord::Base
  has_one :listing
  has_one :saved_search, foreign_key: :search_id

  def self.record_alert(listing_id:, search_id:)
    self.create!(listing_id:, search_id:, sent_at: Time.now)
  end
end
