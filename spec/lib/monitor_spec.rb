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
    # The real client yields once per API request so the caller can record the
    # credit; the stub does the same (one request).
    allow(SociaVaultClient).to receive(:search_from_object) do |&on_request|
      on_request.call
      search_result
    end
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
        email: 'owner@example.com',
        saved_search: saved_search
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

    it 'skips saved searches with invalid coordinates' do
      SavedSearch.delete_all
      bad = SavedSearch.new(query: 'bad', lat: 34.4, long: -11971922006451092, email: 'owner@example.com')
      bad.save!(validate: false)

      expect { monitor.execute_saved_searches }
        .to output(/Skipping 'bad'.*invalid coordinates/).to_stdout
      expect(SociaVaultClient).not_to have_received(:search_from_object)
    end

    it 'outputs the start message' do
      expect { monitor.execute_saved_searches }
        .to output(/🔍 Starting marketplace search/).to_stdout
    end

    it 'records one full run for the pass' do
      expect { monitor.execute_saved_searches }.to change(MonitorRun, :count).by(1)

      run = MonitorRun.last
      expect(run.started_at).not_to be_nil
      expect(run.finished_at).not_to be_nil
    end

    it 'records who initiated the pass' do
      monitor.execute_saved_searches(initiated_by: 'scheduler')

      expect(MonitorRun.last.initiated_by).to eq('scheduler')
    end

    it 'finishes the run even when a search raises' do
      allow(monitor).to receive(:execute_search).and_raise(StandardError, 'boom')

      expect { monitor.execute_saved_searches }.to raise_error(StandardError, 'boom')
      expect(MonitorRun.last.finished_at).not_to be_nil
    end
  end

  describe '#execute_search' do
    let(:search_object) do
      SearchObject.new(
        id: nil,
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

    it 'records an API call against the saved search' do
      expect {
        monitor.send(:execute_search, search_object:, saved_search:)
      }.to change(SearchRun, :count).by(1)
    end

    it 'links the listings it finds to that run' do
      monitor.send(:execute_search, search_object:, saved_search:)

      run = SearchRun.last
      expect(run.listings.map(&:listing_id)).to contain_exactly('1', '2')
    end

    it 'records one run per API request the client made' do
      allow(SociaVaultClient).to receive(:search_from_object) do |&on_request|
        3.times { on_request.call }
        search_result
      end

      expect {
        monitor.send(:execute_search, search_object:, saved_search:)
      }.to change(SearchRun, :count).by(3)
    end

    it 'does not return a listing already alerted for this search' do
      seen = Listing.create!(listing_id: '1', title: 'Seen', search_query: 'apartment')
      Alert.create!(listing_id: seen.id, search_id: saved_search.id, sent_at: Time.now)

      result = monitor.send(:execute_search, search_object:, saved_search:)

      expect(result.map(&:listing_id)).to contain_exactly('2')
    end

    it 'returns a listing that was only alerted for a different search' do
      other = SavedSearch.create!(
        query: 'other', lat: 40.7, long: -74.0, email: 'other@example.com'
      )
      seen = Listing.create!(listing_id: '1', title: 'Seen', search_query: 'other')
      Alert.create!(listing_id: seen.id, search_id: other.id, sent_at: Time.now)

      result = monitor.send(:execute_search, search_object:, saved_search:)

      expect(result.map(&:listing_id)).to contain_exactly('1', '2')
    end

    context 'in dry run' do
      before { allow(Config).to receive(:dry_run?).and_return(true) }

      it 'skips the API call and records no credit' do
        expect(SociaVaultClient).not_to receive(:search_from_object)

        result = nil
        expect {
          result = monitor.send(:execute_search, search_object:, saved_search:)
        }.to output(/DRY RUN/).to_stdout

        expect(result).to eq([])
        expect(SearchRun.count).to eq(0)
      end
    end

    context 'when the API call fails' do
      before do
        allow(SociaVaultClient).to receive(:search_from_object)
          .and_raise(StandardError, 'Connection timeout')
      end

      it 'still records the spent credit as a failed run' do
        expect {
          monitor.send(:execute_search, search_object:, saved_search:)
        }.to change(SearchRun, :count).by(1)

        expect(SearchRun.last.success).to be(false)
      end
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
        emails: ['owner@example.com'],
        query: 'apartment'
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
        id: nil,
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
        id: nil,
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

    it 'soft deletes the saved search' do
      expect {
        monitor.remove_saved_search(id: saved_search.id)
      }.to change { SavedSearch.kept.count }.by(-1)

      expect(saved_search.reload).to be_discarded
    end

    it 'keeps the row and its alert and run history' do
      listing = Listing.create!(listing_id: 'kept-1', title: 'Kept Bike')
      # Alert.record_alert is stubbed for this file, so insert the alert directly.
      Alert.create!(listing_id: listing.id, search_id: saved_search.id, sent_at: Time.now)
      SearchRun.create!(saved_search_id: saved_search.id, success: true)

      monitor.remove_saved_search(id: saved_search.id)

      expect(SavedSearch.count).to eq(1)
      expect(Alert.count).to eq(1)
      expect(SearchRun.count).to eq(1)
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
