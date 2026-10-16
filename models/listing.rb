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
  has_one :saved_search

  # @param [ListingObject] listing_object
  # @param [Integer] search_id
  # @return [Listing]
  def self.add_listing(listing_object:)
    attributes = {
      listing_id: listing_object.id,
      title: listing_object.title,
      price: listing_object.price,
      location: listing_object.location,
      url: listing_object.url,
      image_url: listing_object.image_url,
    }

    now = Time.current

    listing = find_or_initialize_by(listing_id: listing_object.id)
    listing.assign_attributes(attributes)
    listing.first_seen_at ||= now
    listing.last_seen_at = now
    listing.save!

    listing
  end
end
