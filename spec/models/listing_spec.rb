# frozen_string_literal: true

require 'spec_helper'
require_relative '../../models/listing'

RSpec.describe Listing, type: :model do
  subject(:model) { Listing }

  describe '.add_listing' do
    let(:search_query) { 'studio apartment' }

    let(:listing_data) do
      {
        'id' => 12345,
        'title' => 'Cozy Studio in Downtown',
        'price' => { 'amount' => 1500.0 },
        'location' => { 'display_name' => 'Santa Barbara, CA' },
        'url' => 'https://facebook.com/marketplace/item/12345',
        'primary_photo' => { 'url' => 'https://example.com/photo.jpg' }
      }
    end

    before(:each) do
      # Clean up database before each test
      Listing.delete_all
    end

    context 'creating a new listing' do
      it 'creates a listing with the provided data' do
        expect {
          Listing.add_listing(listing_data, search_query)
        }.to change(Listing, :count).by(1)
      end

      it 'sets all attributes correctly' do
        Listing.add_listing(listing_data, search_query)
        listing = Listing.find_by(listing_id: listing_data['id'])

        expect(listing.title).to eq('Cozy Studio in Downtown')
        expect(listing.price).to eq(1500.0)
        expect(listing.location).to eq('Santa Barbara, CA')
        expect(listing.url).to eq('https://facebook.com/marketplace/item/12345')
        expect(listing.image_url).to eq('https://example.com/photo.jpg')
        expect(listing.search_query).to eq('studio apartment')
      end

      it 'sets first_seen_at on creation' do
        Timecop.freeze(Time.parse('2024-01-15 10:00:00')) do
          Listing.add_listing(listing_data, search_query)
          listing = Listing.find_by(listing_id: listing_data['id'])

          expect(listing.first_seen_at).to be_present
          expect(listing.first_seen_at).to be_within(1).of(Time.now)
        end
      end

      it 'sets last_seen_at on creation' do
        Listing.add_listing(listing_data, search_query)
        listing = Listing.find_by(listing_id: listing_data['id'])

        expect(listing.last_seen_at).to be_present
      end
    end

    context 'updating an existing listing' do
      let!(:existing_listing) do
        Listing.create!(
          listing_id: listing_data['id'],
          title: 'Old Title',
          price: 1200.0,
          location: 'Old Location',
          url: 'https://old.url',
          search_query: 'old query',
          first_seen_at: 2.days.ago,
          last_seen_at: 1.day.ago
        )
      end

      it 'updates the listing without creating a new one' do
        expect {
          Listing.add_listing(listing_data, search_query)
        }.not_to change(Listing, :count)
      end

      it 'updates all attributes' do
        Listing.add_listing(listing_data, search_query)
        existing_listing.reload

        expect(existing_listing.title).to eq('Cozy Studio in Downtown')
        expect(existing_listing.price).to eq(1500.0)
        expect(existing_listing.location).to eq('Santa Barbara, CA')
      end

      it 'preserves first_seen_at' do
        original_first_seen = existing_listing.first_seen_at
        Listing.add_listing(listing_data, search_query)
        existing_listing.reload

        expect(existing_listing.first_seen_at).to eq(original_first_seen)
      end

      it 'updates last_seen_at' do
        Timecop.freeze(Time.parse('2024-01-20 15:30:00')) do
          Listing.add_listing(listing_data, search_query)
          existing_listing.reload

          expect(existing_listing.last_seen_at).to be_within(1).of(Time.now)
        end
      end
    end

    context 'handling missing data' do
      it 'handles missing primary_photo gracefully' do
        listing_data['primary_photo'] = nil
        Listing.add_listing(listing_data, search_query)
        listing = Listing.find_by(listing_id: listing_data['id'])

        expect(listing.image_url).to be_nil
      end

      it 'handles primary_photo without url key' do
        listing_data['primary_photo'] = { 'other_key' => 'value' }
        Listing.add_listing(listing_data, search_query)
        listing = Listing.find_by(listing_id: listing_data['id'])

        expect(listing.image_url).to be_nil
      end

      it 'handles null price' do
        listing_data['price']['amount'] = nil
        Listing.add_listing(listing_data, search_query)
        listing = Listing.find_by(listing_id: listing_data['id'])

        expect(listing.price).to be_nil
      end
    end

    context 'with different search queries' do
      it 'updates search_query when called with different search terms' do
        Listing.add_listing(listing_data, 'original query')
        listing = Listing.find_by(listing_id: listing_data['id'])
        expect(listing.search_query).to eq('original query')

        Listing.add_listing(listing_data, 'new query')
        listing.reload
        expect(listing.search_query).to eq('new query')
      end
    end

    context 'validation and data integrity' do
      it 'persists successfully to the database' do
        Listing.add_listing(listing_data, search_query)

        # Fresh query from database
        listing = Listing.find_by(listing_id: listing_data['id'])
        expect(listing).to be_persisted
      end

      it 'handles special characters in title' do
        listing_data['title'] = 'Studio & 1BR - "Luxury" Apt. (Owner Occupied)'
        Listing.add_listing(listing_data, search_query)
        listing = Listing.find_by(listing_id: listing_data['id'])

        expect(listing.title).to eq('Studio & 1BR - "Luxury" Apt. (Owner Occupied)')
      end

      it 'handles long URLs' do
        long_url = 'https://facebook.com/marketplace/item/12345?ref=search&filters[category_id]=3&filters[condition]=1&filters[price_max]=2000'
        listing_data['url'] = long_url
        Listing.add_listing(listing_data, search_query)
        listing = Listing.find_by(listing_id: listing_data['id'])

        expect(listing.url).to eq(long_url)
      end
    end

    context 'concurrent updates' do
      it 'handles race condition gracefully' do
        # Simulate concurrent adds of same listing
        Listing.add_listing(listing_data, 'query 1')
        Listing.add_listing(listing_data, 'query 2')

        # Should only have one listing
        expect(Listing.where(listing_id: listing_data['id']).count).to eq(1)
      end
    end

    context 'timestamps' do
      it 'sets reasonable timestamps' do
        Timecop.freeze(Time.parse('2024-01-15 12:00:00')) do
          Listing.add_listing(listing_data, search_query)
          listing = Listing.find_by(listing_id: listing_data['id'])

          expect(listing.first_seen_at).to be_within(1).of(Time.now)
          expect(listing.last_seen_at).to be_within(1).of(Time.now)
        end
      end
    end
  end

  describe '.create' do
    let(:call) do
      model.create(
        title: 'test',
        listing_id: '123'
      )
    end
    it 'creates a listing' do
      expect(call.title).to eq 'test'
    end

    it 'generates an id' do
      expect(call.id).to be_a Integer
    end

    it 'only has one' do
      call
      expect(Listing.count).to eq 1
    end
  end
end
