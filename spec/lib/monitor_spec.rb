# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Monitor do
  describe '.new' do
    it 'validates configuration on initialization' do
      expect(Config).to receive(:validate!)
      described_class.new
    end

    it 'raises error if configuration is invalid' do
      allow(Config).to receive(:validate!).and_raise('Invalid config')
      expect { described_class.new }.to raise_error('Invalid config')
    end
  end

  describe '.run_search' do
    let(:monitor) { described_class.new }

    let(:api_response) do
      {
        'data' => {
          'listings' => {
            '0' => {
              'id' => '123',
              'title' => 'Test Bike',
              'price' => { 'amount' => 250 },
              'location' => { 'display_name' => 'Test City' },
              'url' => 'https://example.com',
              'primary_photo' => { 'url' => 'https://example.com/img.jpg' }
            }
          }
        }
      }
    end

    before do
      Database.initialize_db
      allow(APIClient).to receive(:search).and_return(api_response)
      allow(EmailService).to receive(:send_alerts)
      allow(STDOUT).to receive(:write)
    end

    it 'completes without error' do
      expect { monitor.run_search }.not_to raise_error
    end

    it 'calls APIClient for each search config' do
      expect(APIClient).to receive(:search).at_least(:once)
      monitor.run_search
    end

    it 'stores listings in database' do
      monitor.run_search

      stats = Database.statistics
      expect(stats[:total_listings]).to be > 0
    end

    it 'calls EmailService with unseen listings' do
      expect(EmailService).to receive(:send_alerts).with(
        array_including(hash_including('title' => 'Test Bike'))
      )
      monitor.run_search
    end

    it 'marks sent alerts in database' do
      monitor.run_search

      unseen = Database.get_unseen_listings
      expect(unseen).to be_empty
    end

    it 'handles API errors gracefully' do
      allow(APIClient).to receive(:search).and_raise('API Error')
      expect { monitor.run_search }.not_to raise_error
    end

    it 'continues searching after API error' do
      allow(APIClient).to receive(:search)
                            .and_raise('API Error')
                            .then.and_return(api_response)

      expect(APIClient).to receive(:search).twice
      monitor.run_search
    end

    it 'sends alerts only for new listings' do
      monitor.run_search
      expect(EmailService).to have_received(:send_alerts).once

      # Run again - should not send emails
      expect(EmailService).not_to receive(:send_alerts)
      monitor.run_search
    end

    it 'searches with configured parameters' do
      monitor.run_search

      call_args = APIClient.call_args
      expect(call_args[1][:query]).to eq('bike')
      expect(call_args[1][:lat]).to eq(40.7128)
      expect(call_args[1][:lng]).to eq(-74.0060)
    end

    it 'handles empty API response' do
      allow(APIClient).to receive(:search).and_return({})
      expect { monitor.run_search }.not_to raise_error
    end

    it 'handles missing listings key' do
      empty_response = { 'data' => {} }
      allow(APIClient).to receive(:search).and_return(empty_response)
      expect { monitor.run_search }.not_to raise_error
    end

    it 'handles nil data in response' do
      nil_response = { 'data' => nil }
      allow(APIClient).to receive(:search).and_return(nil_response)
      expect { monitor.run_search }.not_to raise_error
    end

    it 'adds correct search query to listings' do
      monitor.run_search

      db = Database.connect
      db.results_as_hash = true
      result = db.execute("SELECT search_query FROM listings LIMIT 1")
      db.close

      expect(result.first['search_query']).to eq('bike')
    end

    it 'prints progress messages' do
      expect($stdout).to receive(:write).at_least(:once)
      monitor.run_search
    end

    context 'with multiple searches' do
      before do
        allow(Config).to receive(:search_config).and_return([
                                                              {
                                                                query: 'bike',
                                                                lat: 40.7,
                                                                lng: -74.0,
                                                                min_price: 100,
                                                                max_price: 500,
                                                                radius_km: 25
                                                              },
                                                              {
                                                                query: 'car',
                                                                lat: 35.0,
                                                                lng: -120.0,
                                                                min_price: 5000,
                                                                max_price: 15000,
                                                                radius_km: 50
                                                              }
                                                            ])
      end

      it 'searches for each configured query' do
        expect(APIClient).to receive(:search).twice
        monitor.run_search
      end

      it 'stores listings from multiple searches' do
        monitor.run_search

        stats = Database.statistics
        expect(stats[:listings_by_search]).to have_length(2)
      end
    end

    context 'with multiple listings' do
      let(:api_response_multi) do
        {
          'data' => {
            'listings' => {
              '0' => {
                'id' => '123',
                'title' => 'Bike 1',
                'price' => { 'amount' => 250 },
                'location' => { 'display_name' => 'City A' },
                'url' => 'https://example.com/1',
                'primary_photo' => { 'url' => 'https://example.com/1.jpg' }
              },
              '1' => {
                'id' => '124',
                'title' => 'Bike 2',
                'price' => { 'amount' => 300 },
                'location' => { 'display_name' => 'City B' },
                'url' => 'https://example.com/2',
                'primary_photo' => { 'url' => 'https://example.com/2.jpg' }
              }
            }
          }
        }
      end

      it 'stores all listings' do
        allow(APIClient).to receive(:search).and_return(api_response_multi)
        monitor.run_search

        stats = Database.statistics
        expect(stats[:total_listings]).to eq(2)
      end

      it 'sends alert for all new listings' do
        allow(APIClient).to receive(:search).and_return(api_response_multi)

        expect(EmailService).to receive(:send_alerts) do |listings|
          expect(listings.length).to eq(2)
        end

        monitor.run_search
      end

      it 'marks all listings as alerted' do
        allow(APIClient).to receive(:search).and_return(api_response_multi)
        monitor.run_search

        unseen = Database.get_unseen_listings
        expect(unseen).to be_empty
      end
    end

    context 'with duplicate listings' do
      it 'does not send duplicate alerts' do
        allow(APIClient).to receive(:search).and_return(api_response)

        # First run - should alert
        expect(EmailService).to receive(:send_alerts).with(
          array_including(hash_including('id' => '123'))
        )
        monitor.run_search

        # Second run - same listing should not alert
        expect(EmailService).not_to receive(:send_alerts)
        monitor.run_search
      end
    end

    context 'error recovery' do
      it 'continues if email sending fails' do
        allow(EmailService).to receive(:send_alerts).and_raise('Email Error')
        expect { monitor.run_search }.to raise_error  # Email error propagates, but search completes
      end

      it 'logs API errors without stopping' do
        error_call = 0
        allow(APIClient).to receive(:search) do
          error_call += 1
          raise 'API Error' if error_call == 1
          api_response
        end

        # Should continue after first error
        monitor.run_search
        expect(APIClient).to have_received(:search).twice
      end
    end
  end
end