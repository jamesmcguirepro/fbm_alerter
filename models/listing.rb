# == Schema Information
#
# Table name: listings
#
#  id            :integer          not null, primary key
#  first_seen_at :datetime
#  image_url     :string
#  is_sold       :boolean          default(FALSE)
#  last_seen_at  :datetime
#  location      :string
#  price         :float
#  search_query  :string
#  title         :string           not null
#  url           :string
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  listing_id    :string           not null
#
# Indexes
#
#  index_listings_on_listing_id  (listing_id) UNIQUE
#
class Listing < ActiveRecord::Base
  validates :title, presence: true

  has_many :alerts
  has_one :saved_search

  # @param [ListingObject] listing_object
  # @return [Listing]
  def self.add_listing(listing_object:)
    attributes = {
      listing_id: listing_object.listing_id,
      title: listing_object.title,
      price: listing_object.price,
      location: listing_object.location,
      url: listing_object.url,
      image_url: listing_object.image_url,
      search_query: listing_object.search_query,
    }

    now = Time.current

    listing = find_or_initialize_by(listing_id: listing_object.listing_id)
    listing.assign_attributes(attributes)
    listing.first_seen_at ||= now
    listing.last_seen_at = now
    listing.save!

    listing
  end
end
