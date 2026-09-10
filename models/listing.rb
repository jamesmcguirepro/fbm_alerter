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
#  listing_id    :string          not null, unique
#
class Listing < ActiveRecord::Base
  validates :title, presence: true

  has_many :alerts

  scope :unnotified_and_unsold, lambda {
    left_outer_joins(:alerts)
      .where(alerts: { id: nil }, is_sold: false)
      .order(first_seen_at: :desc)
  }

  def self.add_listing(listing_data, search_query)
    attributes = {
      listing_id: listing_data['id'],
      title: listing_data['title'],
      price: listing_data['price']['amount'],
      location: listing_data['location']['display_name'],
      url: listing_data['url'],
      image_url: listing_data['primary_photo']&.dig('url'),
      search_query:
    }

    now = Time.current

    listing = find_or_initialize_by(listing_id: listing_data['id'])
    listing.assign_attributes(attributes)
    listing.first_seen_at ||= now
    listing.last_seen_at = now
    listing.save
  end
end
