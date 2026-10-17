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
#  search_run_id :integer
#
# Indexes
#
#  index_listings_on_listing_id     (listing_id) UNIQUE
#  index_listings_on_search_run_id  (search_run_id)
#
# Foreign Keys
#
#  search_run_id  (search_run_id => search_runs.id)
#
class Listing < ActiveRecord::Base
  validates :title, presence: true

  has_many :alerts
  # The run that first discovered this listing (nil for listings seen before
  # run tracking, or ad-hoc CLI searches).
  belongs_to :search_run, optional: true

  # @param [ListingObject] listing_object
  # @param [SearchRun, nil] search_run the run that found it (stamped once)
  # @return [Listing]
  def self.add_listing(listing_object:, search_run: nil)
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
    # Only the discovery run is recorded; later runs that merely re-see a
    # listing must not claim it.
    listing.search_run = search_run if listing.new_record? && search_run
    listing.first_seen_at ||= now
    listing.last_seen_at = now
    listing.save!

    listing
  end
end
