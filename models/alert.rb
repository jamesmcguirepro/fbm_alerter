# == Schema Information
#
# Table name: alerts
#
#  id         :integer          not null, primary key
#  listing_id :integer
#  sent_at    :datetime
#
class Alert < ActiveRecord::Base
  has_one :listing

  def self.record_alert(listing_id:)
    self.create!(listing_id:, sent_at: Time.now)
  end
end
