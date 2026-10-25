# frozen_string_literal: true

require 'spec_helper'
require 'webmock/rspec'

RSpec.describe 'Marketplace Monitor integration' do
  let(:api_endpoint) { 'https://api.sociavault.com/v1/scrape/facebook-marketplace/search' }

  let(:search_response) do
    {
      'data' => {
        'listings' => {
          '1' => {
            'id' => 'fb-1001',
            'title' => 'Mountain Bike - Like New',
            'price' => { 'amount' => 350 },
            'location' => { 'display_name' => 'Austin, TX' },
            'url' => 'https://facebook.com/marketplace/item/1001/',
            'primary_photo' => { 'url' => 'https://example.com/photo1.jpg' },
            'is_sold' => false
          },
          '2' => {
            'id' => 'fb-1002',
            'title' => 'Road Bike',
            'price' => { 'amount' => 450 },
            'location' => { 'display_name' => 'Austin, TX' },
            'url' => 'https://facebook.com/marketplace/item/1002/',
            'primary_photo' => { 'url' => 'https://example.com/photo2.jpg' },
            'is_sold' => false
          }
        }
      }
    }
  end

  let!(:saved_search) do
    SavedSearch.create!(
      query: 'bike',
      lat: 30.2677,
      long: -97.7475,
      min_price: 100,
      max_price: 500,
      radius_km: 65,
      email: 'owner@example.com'
    )
  end

  def stub_api_success(response = search_response)
    stub_request(:get, api_endpoint)
      .with(
        query: hash_including(
          query: 'bike',
          lat: '30.2677',
          lng: '-97.7475',
          radius_km: '65',
          count: '100'
        ),
        headers: { 'X-API-Key' => 'sk_test_key' }
      )
      .to_return(
        status: 200,
        body: JSON.generate(response),
        headers: { 'Content-Type' => 'application/json' }
      )
  end

  def stub_api_empty
    stub_request(:get, api_endpoint)
      .with(query: hash_including(query: 'bike'))
      .to_return(
        status: 200,
        body: JSON.generate({ 'data' => { 'listings' => {} } }),
        headers: { 'Content-Type' => 'application/json' }
      )
  end

  def stub_api_error(status_code, body)
    stub_request(:get, api_endpoint)
      .with(query: hash_including(query: 'bike'))
      .to_return(
        status: status_code,
        body: JSON.generate(body),
        headers: { 'Content-Type' => 'application/json' }
      )
  end

  describe 'full search cycle' do
    before do
      stub_api_success
      # Stub email delivery to avoid actual SMTP
      allow(Mailer).to receive(:send_email).and_return(true)
    end

    it 'creates listings from API response' do
      expect {
        MarketplaceMonitor.new.execute_saved_searches
      }.to change(Listing, :count).by(2)
    end

    it 'creates listings with correct attributes' do
      MarketplaceMonitor.new.execute_saved_searches

      listing = Listing.find_by(listing_id: 'fb-1001')
      expect(listing).not_to be_nil
      expect(listing.title).to eq('Mountain Bike - Like New')
      expect(listing.price).to eq(350)
      expect(listing.location).to eq('Austin, TX')
      expect(listing.url).to eq('https://facebook.com/marketplace/item/1001/')
      expect(listing.image_url).to eq('https://example.com/photo1.jpg')
      expect(listing.search_query).to eq('bike')
      expect(listing.is_sold).to be false
    end

    it 'records alerts for new listings' do
      expect {
        MarketplaceMonitor.new.execute_saved_searches
      }.to change(Alert, :count).by(2)
    end

    it 'associates alerts with the correct listing and search' do
      MarketplaceMonitor.new.execute_saved_searches

      listing = Listing.find_by(listing_id: 'fb-1001')
      alert = Alert.find_by(listing_id: listing.id)
      expect(alert.search_id).to eq(saved_search.id)
      expect(alert.sent_at).to be_present
    end

    it 'sends email alerts' do
      MarketplaceMonitor.new.execute_saved_searches

      expect(Mailer).to have_received(:send_email).once
      expect(Mailer).to have_received(:send_email) do |args|
        expect(args[:to]).to eq('owner@example.com')
        expect(args[:from]).to eq('test@example.com')
        expect(args[:subject]).to include('new listings (2 exact) for "bike"')
        expect(args[:html_body]).to include('Mountain Bike - Like New')
        expect(args[:html_body]).to include('Road Bike')
      end
    end

    it 'does not create duplicate listings on re-run' do
      MarketplaceMonitor.new.execute_saved_searches
      expect(Listing.count).to eq(2)

      # Stub again for the second run
      stub_api_success
      expect {
        MarketplaceMonitor.new.execute_saved_searches
      }.not_to change(Listing, :count)
    end

    it 'updates last_seen_at on re-run without changing first_seen_at' do
      Timecop.freeze(Time.parse('2024-01-15 10:00:00')) do
        MarketplaceMonitor.new.execute_saved_searches
      end

      listing = Listing.find_by(listing_id: 'fb-1001')
      original_first_seen = listing.first_seen_at

      Timecop.travel(1.day) do
        stub_api_success
        MarketplaceMonitor.new.execute_saved_searches
      end

      listing.reload
      expect(listing.first_seen_at).to eq(original_first_seen)
      expect(listing.last_seen_at).to be > original_first_seen
    end
  end

  describe 'empty API response' do
    before do
      stub_api_empty
      allow(Mailer).to receive(:send_email).and_return(true)
    end

    it 'does not create listings' do
      expect {
        MarketplaceMonitor.new.execute_saved_searches
      }.not_to change(Listing, :count)
    end

    it 'does not send alerts' do
      MarketplaceMonitor.new.execute_saved_searches
      expect(Mailer).not_to have_received(:send_email)
    end
  end

  describe 'API error handling' do
    before do
      allow(Mailer).to receive(:send_email).and_return(true)
    end

    context '401 Unauthorized' do
      before do
        stub_api_error(401, { 'error' => 'Invalid API key' })
      end

      it 'does not crash and logs the error' do
        expect {
          MarketplaceMonitor.new.execute_saved_searches
        }.not_to raise_error
      end

      it 'does not create listings' do
        expect {
          MarketplaceMonitor.new.execute_saved_searches
        }.not_to change(Listing, :count)
      end
    end

    context '402 Insufficient Credits' do
      before do
        stub_api_error(402, { 'required' => 1, 'available' => 0 })
      end

      it 'does not crash' do
        expect {
          MarketplaceMonitor.new.execute_saved_searches
        }.not_to raise_error
      end
    end

    context '500 Server Error' do
      before do
        stub_api_error(500, { 'error' => 'Internal server error' })
      end

      it 'does not crash' do
        expect {
          MarketplaceMonitor.new.execute_saved_searches
        }.not_to raise_error
      end
    end
  end
end
