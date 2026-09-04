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
end
