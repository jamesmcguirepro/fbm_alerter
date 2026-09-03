# frozen_string_literal: true

require 'spec_helper'

describe MarketplaceMonitor::Database do
  before(:each) do
    described_class.initialize_db
  end

  describe '.initialize_db' do
    it 'creates listings table' do
      db = described_class.connect
      tables = db.execute("SELECT name FROM sqlite_master WHERE type='table' AND name='listings'")
      expect(tables).not_to be_empty
      db.close
    end

    it 'creates alerts_sent table' do
      db = described_class.connect
      tables = db.execute("SELECT name FROM sqlite_master WHERE type='table' AND name='alerts_sent'")
      expect(tables).not_to be_empty
      db.close
    end

    it 'is idempotent' do
      expect { described_class.initialize_db }.not_to raise_error
      expect { described_class.initialize_db }.not_to raise_error
    end
  end

  describe '.add_listing' do
    let(:listing_data) do
      {
        'id' => '123456',
        'title' => 'Mountain Bike',
        'price' => { 'amount' => 250 },
        'location' => { 'display_name' => 'Austin, TX' },
        'url' => 'https://facebook.com/marketplace/item/123456/',
        'primary_photo' => { 'url' => 'https://example.com/image.jpg' }
      }
    end

    it 'inserts a new listing' do
      described_class.add_listing(listing_data, 'bike')

      db = described_class.connect
      db.results_as_hash = true
      result = db.execute("SELECT * FROM listings WHERE id = ?", ['123456'])
      db.close

      expect(result).to have_length(1)
      expect(result.first['title']).to eq('Mountain Bike')
      expect(result.first['price']).to eq(250)
    end

    it 'stores search query' do
      described_class.add_listing(listing_data, 'mountain bike')

      db = described_class.connect
      db.results_as_hash = true
      result = db.execute("SELECT search_query FROM listings WHERE id = ?", ['123456'])
      db.close

      expect(result.first['search_query']).to eq('mountain bike')
    end

    it 'ignores duplicates on insert' do
      described_class.add_listing(listing_data, 'bike')
      described_class.add_listing(listing_data, 'bike')

      db = described_class.connect
      count = db.execute("SELECT COUNT(*) as count FROM listings").first['count']
      db.close

      expect(count).to eq(1)
    end

    it 'updates last_seen_at on re-insert' do
      described_class.add_listing(listing_data, 'bike')

      db = described_class.connect
      first_seen = db.execute("SELECT first_seen_at FROM listings WHERE id = ?", ['123456']).first['first_seen_at']
      db.close

      sleep(0.1)
      described_class.add_listing(listing_data, 'bike')

      db = described_class.connect
      last_seen = db.execute("SELECT last_seen_at FROM listings WHERE id = ?", ['123456']).first['last_seen_at']
      db.close

      expect(last_seen).not_to eq(first_seen)
    end

    it 'handles nil image_url' do
      listing_data['primary_photo'] = nil
      described_class.add_listing(listing_data, 'bike')

      db = described_class.connect
      db.results_as_hash = true
      result = db.execute("SELECT image_url FROM listings WHERE id = ?", ['123456'])
      db.close

      expect(result.first['image_url']).to be_nil
    end
  end

  describe '.get_unseen_listings' do
    let(:listing_data) do
      {
        'id' => '123',
        'title' => 'Test Item',
        'price' => { 'amount' => 100 },
        'location' => { 'display_name' => 'Test City' },
        'url' => 'https://example.com',
        'primary_photo' => { 'url' => 'https://example.com/img.jpg' }
      }
    end

    it 'returns empty array initially' do
      listings = described_class.get_unseen_listings
      expect(listings).to eq([])
    end

    it 'returns new listings' do
      described_class.add_listing(listing_data, 'test')
      listings = described_class.get_unseen_listings
      expect(listings).to have_length(1)
      expect(listings.first['title']).to eq('Test Item')
    end

    it 'excludes alerted listings' do
      described_class.add_listing(listing_data, 'test')
      described_class.mark_alert_sent('123')
      listings = described_class.get_unseen_listings
      expect(listings).to be_empty
    end

    it 'excludes sold listings' do
      described_class.add_listing(listing_data, 'test')
      described_class.mark_sold('123')
      listings = described_class.get_unseen_listings
      expect(listings).to be_empty
    end

    it 'returns multiple unseen listings' do
      described_class.add_listing(listing_data, 'test')

      listing_data['id'] = '124'
      described_class.add_listing(listing_data, 'test')

      listings = described_class.get_unseen_listings
      expect(listings).to have_length(2)
    end
  end

  describe '.mark_alert_sent' do
    let(:listing_data) do
      {
        'id' => '123',
        'title' => 'Test',
        'price' => { 'amount' => 100 },
        'location' => { 'display_name' => 'Test' },
        'url' => 'https://example.com',
        'primary_photo' => { 'url' => 'https://example.com/img.jpg' }
      }
    end

    it 'creates alert_sent record' do
      described_class.add_listing(listing_data, 'test')
      described_class.mark_alert_sent('123')

      db = described_class.connect
      result = db.execute("SELECT COUNT(*) as count FROM alerts_sent WHERE listing_id = ?", ['123'])
      db.close

      expect(result.first['count']).to eq(1)
    end

    it 'prevents duplicate listings from appearing in unseen' do
      described_class.add_listing(listing_data, 'test')
      expect(described_class.get_unseen_listings).to have_length(1)

      described_class.mark_alert_sent('123')
      expect(described_class.get_unseen_listings).to be_empty
    end
  end

  describe '.mark_sold' do
    let(:listing_data) do
      {
        'id' => '123',
        'title' => 'Test',
        'price' => { 'amount' => 100 },
        'location' => { 'display_name' => 'Test' },
        'url' => 'https://example.com',
        'primary_photo' => { 'url' => 'https://example.com/img.jpg' }
      }
    end

    it 'sets is_sold to 1' do
      described_class.add_listing(listing_data, 'test')
      described_class.mark_sold('123')

      db = described_class.connect
      db.results_as_hash = true
      result = db.execute("SELECT is_sold FROM listings WHERE id = ?", ['123'])
      db.close

      expect(result.first['is_sold']).to eq(1)
    end

    it 'excludes from unseen listings' do
      described_class.add_listing(listing_data, 'test')
      described_class.mark_sold('123')
      expect(described_class.get_unseen_listings).to be_empty
    end
  end

  describe '.statistics' do
    let(:listing_data) do
      {
        'id' => '123',
        'title' => 'Test',
        'price' => { 'amount' => 100 },
        'location' => { 'display_name' => 'Test' },
        'url' => 'https://example.com',
        'primary_photo' => { 'url' => 'https://example.com/img.jpg' }
      }
    end

    it 'returns statistics hash' do
      stats = described_class.statistics
      expect(stats).to include(:total_listings, :total_alerts_sent, :sold_listings, :listings_by_search)
    end

    it 'counts total listings' do
      described_class.add_listing(listing_data, 'bike')
      listing_data['id'] = '124'
      described_class.add_listing(listing_data, 'bike')

      stats = described_class.statistics
      expect(stats[:total_listings]).to eq(2)
    end

    it 'counts alerts sent' do
      described_class.add_listing(listing_data, 'bike')
      described_class.mark_alert_sent('123')

      stats = described_class.statistics
      expect(stats[:total_alerts_sent]).to eq(1)
    end

    it 'counts sold listings' do
      described_class.add_listing(listing_data, 'bike')
      described_class.mark_sold('123')

      stats = described_class.statistics
      expect(stats[:sold_listings]).to eq(1)
    end

    it 'groups by search query' do
      described_class.add_listing(listing_data, 'bike')
      listing_data['id'] = '124'
      described_class.add_listing(listing_data, 'car')

      stats = described_class.statistics
      expect(stats[:listings_by_search]).to have_length(2)
    end
  end

  describe '.cleanup_old_listings' do
    let(:listing_data) do
      {
        'id' => '123',
        'title' => 'Test',
        'price' => { 'amount' => 100 },
        'location' => { 'display_name' => 'Test' },
        'url' => 'https://example.com',
        'primary_photo' => { 'url' => 'https://example.com/img.jpg' }
      }
    end

    it 'deletes old listings' do
      described_class.add_listing(listing_data, 'test')

      db = described_class.connect
      # Update created date to 31 days ago
      db.execute(
        "UPDATE listings SET first_seen_at = datetime('now', '-31 days') WHERE id = ?",
        ['123']
      )
      db.close

      deleted = described_class.cleanup_old_listings(30)
      expect(deleted).to eq(1)
      expect(described_class.statistics[:total_listings]).to eq(0)
    end

    it 'keeps recent listings' do
      described_class.add_listing(listing_data, 'test')

      deleted = described_class.cleanup_old_listings(30)
      expect(deleted).to eq(0)
      expect(described_class.statistics[:total_listings]).to eq(1)
    end
  end

  describe '.export_to_json' do
    let(:listing_data) do
      {
        'id' => '123',
        'title' => 'Test Item',
        'price' => { 'amount' => 100 },
        'location' => { 'display_name' => 'Test City' },
        'url' => 'https://example.com',
        'primary_photo' => { 'url' => 'https://example.com/img.jpg' }
      }
    end

    it 'exports listings to JSON file' do
      described_class.add_listing(listing_data, 'test')
      filename = described_class.export_to_json('test_export.json')

      expect(File.exist?(filename)).to be true

      json_data = JSON.parse(File.read(filename))
      expect(json_data).to be_an(Array)
      expect(json_data.first['title']).to eq('Test Item')

      File.delete(filename)
    end

    it 'uses default filename' do
      filename = described_class.export_to_json
      expect(filename).to eq('listings_export.json')
      File.delete(filename) if File.exist?(filename)
    end
  end
end