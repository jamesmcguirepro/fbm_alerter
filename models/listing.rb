# == Schema Information
#
# Table name: listings
#
#  id            :integer          not null, primary key
#  title         :string           not null
#  price         :float
#  location      :string
#  url           :string
#  image_url     :string
#  search_query  :string
#  first_seen_at :datetime
#  last_seen_at  :datetime
#  is_sold       :boolean
#
class Listing < ActiveRecord::Base
  validates :title, presence: true

  has_many :alerts

  scope :unnotified_and_unsold, -> {
    left_outer_joins(:alerts_sent)
      .where(alerts_sent: { id: nil }, is_sold: false)
      .order(first_seen_at: :desc)
  }
end
