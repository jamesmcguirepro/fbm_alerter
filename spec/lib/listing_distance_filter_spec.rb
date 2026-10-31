# frozen_string_literal: true

require 'spec_helper'
require_relative '../../lib/listing_distance_filter'
require_relative '../../lib/geocode_cache'

RSpec.describe ListingDistanceFilter do
  let(:search_object) do
    SearchObject.new(
      id: nil, query: 'test', lat: 40.7128, long: -74.0060,
      min_price: nil, max_price: nil, radius_mi: 65,
      condition: nil, delivery_method: nil
    )
  end

  let(:filter) { described_class.new(radius_km: Distance.miles_to_km(65)) }

  def make_listing(location:, is_sold: nil)
    ListingObject.new(
      listing_id: '1', title: 'Test', price: 100, location:, url: 'http://x',
      image_url: nil, search_query: 'test', listed_at: Time.current,
      first_seen_at: nil, last_seen_at: nil, is_sold: is_sold
    )
  end

  describe '#filter' do
    before do
      filter.before_search(search_object)
    end

    it 'passes listings without a location through' do
      listing = make_listing(location: nil)

      expect(filter.filter(listing, search_object)).to be(true)
    end

    it 'passes listings beyond the radius through when geocoding fails' do
      stub_request(:get, %r{nominatim\.openstreetmap\.org/search})
        .to_return(status: 200, body: '[]')

      listing = make_listing(location: 'Unknown City, ZZ')

      expect(filter.filter(listing, search_object)).to be(true)
    end

    it 'drops listings beyond the radius' do
      # Miami is ~1100 km from NYC, well beyond 65 mi (105 km)
      stub_request(:get, 'https://nominatim.openstreetmap.org/search')
        .with(query: hash_including(q: 'miami, florida'))
        .to_return(status: 200, body: [
                     { 'lat' => '25.7617', 'lon' => '-80.1918', 'display_name' => 'Miami, Florida' }
                   ].to_json,
                   headers: { 'Content-Type' => 'application/json' })

      listing = make_listing(location: 'Miami, FL')

      expect(filter.filter(listing, search_object)).to be(false)
    end

    it 'keeps listings within the radius' do
      # New Rochelle is ~25 miles from NYC, within 65 mi
      stub_request(:get, 'https://nominatim.openstreetmap.org/search')
        .with(query: hash_including(q: 'new rochelle, new york'))
        .to_return(status: 200, body: [
                     { 'lat' => '40.91', 'lon' => '-73.79', 'display_name' => 'New Rochelle, New York' }
                   ].to_json,
                   headers: { 'Content-Type' => 'application/json' })

      listing = make_listing(location: 'New Rochelle, NY')

      expect(filter.filter(listing, search_object)).to be(true)
    end

    it 'normalizes listing location strings' do
      # "US / Austin, TX" should normalize to "austin, texas" for the cache key
      # and be sent as q: "austin, texas" to Nominatim
      stub_request(:get, 'https://nominatim.openstreetmap.org/search')
        .with(query: hash_including(q: 'austin, texas'))
        .to_return(status: 200, body: [
                     { 'lat' => '30.2672', 'lon' => '-97.7431', 'display_name' => 'Austin, Texas' }
                   ].to_json,
                   headers: { 'Content-Type' => 'application/json' })

      listing = make_listing(location: 'US / Austin, TX')

      # Austin is ~1800 km from NYC, beyond 65 mi — should be filtered out
      expect(filter.filter(listing, search_object)).to be(false)
    end
  end

  describe '#after_search' do
    before do
      filter.before_search(search_object)
    end

    it 'reports geocode lookups to stats' do
      # Stub to avoid real HTTP calls — we just want to verify the counter
      stub_request(:get, %r{nominatim\.openstreetmap\.org/search})
        .to_return(status: 200, body: [
                     { 'lat' => '40.91', 'lon' => '-73.79', 'display_name' => 'New Rochelle, NY' }
                   ].to_json,
                   headers: { 'Content-Type' => 'application/json' })

      stats = {}
      listing = make_listing(location: 'New Rochelle, NY')

      filter.filter(listing, search_object)
      filter.filter(listing, search_object)
      filter.filter(listing, search_object)

      filter.after_search(stats)

      expect(stats[:geocode_lookups]).to eq(3)
    end
  end
end
