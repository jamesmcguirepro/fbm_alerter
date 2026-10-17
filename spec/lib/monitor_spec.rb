# frozen_string_literal: true

require 'spec_helper'

RSpec.describe MarketplaceMonitor do
  subject(:monitor) { described_class.new }

  let!(:saved_search) do
    SavedSearch.create!(
      query: 'apartment',
      lat: 40.7128,
      long: -74.0060,
      min_price: 100,
      max_price: 500,
      radius_km: 25,
      email: 'owner@example.com'
    )
  end

  let(:search_result) do
    {
      'data' => {
        'listings' => {
          '1' => {
            'id' => '1',
            'title' => 'Cozy Apt',
            'price' => { 'amount' => 200 },
            'location' => { 'display_name' => 'NYC' },
            'url' => 'https://example.com/1',
            'primary_photo' => { 'url' => 'https://example.com/photo.jpg' },
            'is_sold' => false
          },
          '2' => {
            'id' => '2',
            'title' => 'Spacious House',
            'price' => { 'amount' => 400 },
            'location' => { 'display_name' => 'Brooklyn, NY' },
            'url' => 'https://example.com/2',
            'primary_photo' => { 'url' => 'https://example.com/photo2.jpg' },
            'is_sold' => false
          }
        }
      }
    }
  end

  before do
    allow(Config).to receive(:validate!)
    allow(SociaVaultClient).to receive(:search_from_object).and_return(search_result)
    allow(EmailService).to receive(:send_alerts)
    allow(Alert).to receive(:record_alert)
  end

  describe '#initialize' do
    it 'validates the configuration' do
      expect(Config).to receive(:validate!)
      described_class.new
    end
  end

  describe '#execute_saved_searches' do
    it 'iterates through each saved search in the database' do
      SavedSearch.create!(
        query: 'house',
        lat: 40.7128,
        long: -74.0060,
        min_price: 200,
        max_price: 800,
        radius_km: 25,
        email: 'owner@example.com'
      )

      monitor.execute_saved_searches

      expect(SociaVaultClient).to have_received(:search_from_object).twice
    end

    it 'calls execute_search for each saved search' do
      allow(monitor).to receive(:execute_search).and_return([])
      allow(monitor).to receive(:send_alerts)

      monitor.execute_saved_searches

      expect(monitor).to have_received(:execute_search).with(
        search_object: an_instance_of(SearchObject),
        email: 'owner@example.com'
      ).at_least(:once)
    end

    it 'sends alerts for new listings found' do
      new_listing = Listing.create!(
        listing_id: 'new-1',
        title: 'New Listing',
        price: 200,
        location: 'NYC',
        url: 'https://example.com/new-1',
        search_query: 'apartment'
      )
      allow(monitor).to receive(:execute_search).and_return([new_listing])
      allow(monitor).to receive(:send_alerts)

      monitor.execute_saved_searches

      expect(monitor).to have_received(:send_alerts).with(
        listings: [new_listing],
        saved_search: saved_search
      )
    end

    it 'does not call the API when there are no saved searches' do
      SavedSearch.delete_all

      monitor.execute_saved_searches

      expect(SociaVaultClient).not_to have_received(:search_from_object)
    end

    it 'outputs the start message' do
      expect { monitor.execute_saved_searches }
        .to output(/🔍 Starting marketplace search/).to_stdout
    end
  end

  describe '#execute_search' do
    let(:search_object) do
      SearchObject.new(
        query: 'apartment',
        lat: 40.7128,
        long: -74.0060,
        min_price: 100,
        max_price: 500,
        radius_km: 25,
        condition: nil,
        delivery_method: nil
      )
    end

    it 'calls SociaVaultClient with the search object' do
      monitor.send(:execute_search, search_object:, email: 'test@example.com')

      expect(SociaVaultClient).to have_received(:search_from_object).with(search_object:)
    end

    it 'adds each new listing to the database' do
      monitor.send(:execute_search, search_object:, email: 'test@example.com')

      expect(Listing.where(listing_id: '1').count).to eq(1)
      expect(Listing.where(listing_id: '2').count).to eq(1)
    end

    it 'returns the new listings' do
      result = monitor.send(:execute_search, search_object:, email: 'test@example.com')

      expect(result.length).to eq(2)
      expect(result.first).to be_a(Listing)
    end

    it 'outputs the search query and location' do
      expect { monitor.send(:execute_search, search_object:, email: 'test@example.com') }
        .to output(/Searching: apartment/).to_stdout
    end

    it 'outputs the number of listings found' do
      expect { monitor.send(:execute_search, search_object:, email: 'test@example.com') }
        .to output(/Found 2 listing/).to_stdout
    end

    context 'when a listing already exists' do
      before do
        Listing.create!(
          listing_id: '1',
          title: 'Existing',
          location: 'NYC',
          url: 'https://example.com/1',
          search_query: 'apartment'
        )
        Listing.create!(
          listing_id: '2',
          title: 'Existing 2',
          location: 'Brooklyn, NY',
          url: 'https://example.com/2',
          search_query: 'apartment'
        )
      end

      it 'does not create duplicates' do
        expect {
          monitor.send(:execute_search, search_object:, email: 'test@example.com')
        }.not_to change(Listing, :count)
      end
    end

    context 'when API returns empty listings' do
      before do
        allow(SociaVaultClient).to receive(:search_from_object)
          .and_return({ 'data' => { 'listings' => {} } })
      end

      it 'does not add listings' do
        expect {
          monitor.send(:execute_search, search_object:, email: 'test@example.com')
        }.not_to change(Listing, :count)
      end

      it 'outputs appropriate message' do
        expect { monitor.send(:execute_search, search_object:, email: 'test@example.com') }
          .to output(/No listings found/).to_stdout
      end
    end

    context 'when API returns unexpected format' do
      before do
        allow(SociaVaultClient).to receive(:search_from_object).and_return({})
      end

      it 'does not add listings' do
        expect {
          monitor.send(:execute_search, search_object:, email: 'test@example.com')
        }.not_to change(Listing, :count)
      end

      it 'outputs the unexpected response message' do
        expect { monitor.send(:execute_search, search_object:, email: 'test@example.com') }
          .to output(/No listings found or unexpected response format/).to_stdout
      end
    end

    context 'when API call raises an error' do
      before do
        allow(SociaVaultClient).to receive(:search_from_object)
          .and_raise(StandardError, 'Connection timeout')
      end

      it 'catches the error and continues' do
        expect { monitor.send(:execute_search, search_object:, email: 'test@example.com') }
          .not_to raise_error
      end

      it 'outputs the error message' do
        expect { monitor.send(:execute_search, search_object:, email: 'test@example.com') }
          .to output(/✗ Error: Connection timeout/).to_stdout
      end

      it 'does not add listings' do
        expect {
          monitor.send(:execute_search, search_object:, email: 'test@example.com')
        }.not_to change(Listing, :count)
      end
    end
  end

  describe '#send_alerts' do
    let(:new_listing) do
      Listing.create!(
        listing_id: 'alert-1',
        title: 'Test Listing',
        price: 200,
        location: 'NYC',
        url: 'https://example.com/1',
        search_query: 'apartment'
      )
    end

    it 'sends alerts via EmailService' do
      monitor.send(:send_alerts, listings: [new_listing], saved_search:)

      expect(EmailService).to have_received(:send_alerts).with(
        listings: [new_listing],
        emails: ['owner@example.com']
      )
    end

    it 'records an alert for each listing' do
      monitor.send(:send_alerts, listings: [new_listing], saved_search:)

      expect(Alert).to have_received(:record_alert).with(
        listing_id: new_listing.id,
        search_id: saved_search.id
      )
    end

    it 'outputs the number of alerts sent' do
      expect { monitor.send(:send_alerts, listings: [new_listing], saved_search:) }
        .to output(/📧 Sending alerts for 1 new listing/).to_stdout
    end

    context 'when there are no new listings' do
      it 'does not send alerts' do
        monitor.send(:send_alerts, listings: [], saved_search:)

        expect(EmailService).not_to have_received(:send_alerts)
      end

      it 'does not record any alerts' do
        monitor.send(:send_alerts, listings: [], saved_search:)

        expect(Alert).not_to have_received(:record_alert)
      end

      it 'outputs the no new listings message' do
        expect { monitor.send(:send_alerts, listings: [], saved_search:) }
          .to output(/✓ No new listings to alert/).to_stdout
      end
    end
  end

  describe '#search' do
    let(:search_object) do
      SearchObject.new(
        query: 'apartment',
        lat: 40.7128,
        long: -74.0060,
        min_price: 100,
        max_price: 500,
        radius_km: 25,
        condition: nil,
        delivery_method: nil
      )
    end

    it 'calls execute_search with the search object' do
      allow(monitor).to receive(:execute_search).and_return([])

      monitor.search(search_object:)

      expect(monitor).to have_received(:execute_search).with(search_object:)
    end
  end

  describe '#add_saved_search' do
    let(:search_object) do
      SearchObject.new(
        query: 'bike',
        lat: 40.7128,
        long: -74.0060,
        min_price: 100,
        max_price: 500,
        radius_km: 25,
        condition: nil,
        delivery_method: nil
      )
    end

    it 'delegates to SavedSearch.add_search' do
      expect(SavedSearch).to receive(:add_search).with(search_object:, email: 'owner@example.com')

      monitor.add_saved_search(search_object:, email: 'owner@example.com')
    end
  end

  describe '#remove_saved_search' do
    let!(:saved_search) do
      SavedSearch.create!(
        query: 'bike',
        lat: 40.7128,
        long: -74.0060,
        min_price: 100,
        max_price: 500,
        radius_km: 25,
        email: 'owner@example.com'
      )
    end

    it 'deletes the saved search' do
      expect {
        monitor.remove_saved_search(id: saved_search.id)
      }.to change(SavedSearch, :count).by(-1)
    end

    it 'outputs the deleted search ID' do
      expect { monitor.remove_saved_search(id: saved_search.id) }
        .to output(/Deleted search ID #{saved_search.id}/).to_stdout
    end

    it 'prints the search before deleting' do
      expect { monitor.remove_saved_search(id: saved_search.id) }
        .to output(/ID: #{saved_search.id}/).to_stdout
    end
  end

  describe '#list_saved_searches' do
    let!(:saved_search) do
      SavedSearch.create!(
        query: 'bike',
        lat: 40.7128,
        long: -74.0060,
        min_price: 100,
        max_price: 500,
        radius_km: 25,
        email: 'owner@example.com'
      )
    end

    it 'lists all saved searches' do
      expect { monitor.list_saved_searches }
        .to output(/ID: #{saved_search.id}/).to_stdout
    end
  end
end
