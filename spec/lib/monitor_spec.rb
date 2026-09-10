# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Monitor do
  subject(:monitor) { described_class.new }

  let(:search_config) do
    [
      { query: 'apartment', lat: 40.7128, long: -74.0060 },
      { query: 'house', lat: 40.7128, long: -74.0060 }
    ]
  end

  let(:search_result) do
    {
      'data' => {
        'listings' => {
          '1' => { 'id' => '1', 'title' => 'Cozy Apt' },
          '2' => { 'id' => '2', 'title' => 'Spacious House' }
        }
      }
    }
  end

  let(:unseen_listings) do
    [
      { 'id' => '1', 'title' => 'Cozy Apt' },
      { 'id' => '2', 'title' => 'Spacious House' }
    ]
  end

  before do
    allow(Alert).to receive(:record_alert)
    allow(Config).to receive(:validate!)
    allow(Config).to receive(:search_config).and_return(search_config)
    allow(EmailService).to receive(:send_alerts)
    allow(Listing).to receive(:add_listing)
    allow(Listing).to receive(:unnotified_and_unsold).and_return(unseen_listings)
    allow(SociaVaultClient).to receive(:search).and_return(search_result)
  end

  describe '#initialize' do
    it 'validates the configuration' do
      expect(Config).to receive(:validate!)
      described_class.new
    end
  end

  describe '#run_search' do
    it 'iterates through each search configuration' do
      expect(Config).to receive(:search_config).and_return(search_config)

      monitor.run_search

      expect(SociaVaultClient).to have_received(:search).twice
    end

    it 'calls monitor_search for each configured search' do
      allow(monitor).to receive(:monitor_search)

      monitor.run_search

      search_config.each do |search|
        expect(monitor).to have_received(:monitor_search).with(search)
      end
    end

    it 'sends alerts after all searches complete' do
      allow(monitor).to receive(:send_alerts)

      monitor.run_search

      expect(monitor).to have_received(:send_alerts)
    end

    it 'outputs the start message' do
      expect { monitor.run_search }.to output(/🔍 Starting marketplace search/).to_stdout
    end
  end

  describe '#monitor_search' do
    let(:search) { search_config.first }

    it 'calls SociaVaultClient with search parameters' do
      monitor.send(:monitor_search, search)

      expect(SociaVaultClient).to have_received(:search).with(**search)
    end

    it 'adds each listing' do
      monitor.send(:monitor_search, search)

      search_result['data']['listings'].each_value do |listing|
        expect(Listing).to have_received(:add_listing).with(listing, search[:query])
      end
    end

    it 'outputs the search query and location' do
      expect { monitor.send(:monitor_search, search) }
        .to output(/Searching: #{search[:query]}/).to_stdout
    end

    it 'outputs the number of listings found' do
      expect { monitor.send(:monitor_search, search) }
        .to output(/Found 2 listing/).to_stdout
    end

    context 'when API returns empty listings' do
      before do
        allow(SociaVaultClient).to receive(:search)
          .and_return({ 'data' => { 'listings' => {} } })
      end

      it 'does not add listings' do
        monitor.send(:monitor_search, search)

        expect(Listing).not_to have_received(:add_listing)
      end

      it 'outputs appropriate message' do
        expect { monitor.send(:monitor_search, search) }
          .to output(/No listings found/).to_stdout
      end
    end

    context 'when API returns unexpected format' do
      before do
        allow(SociaVaultClient).to receive(:search).and_return({})
      end

      it 'does not add listings' do
        monitor.send(:monitor_search, search)

        expect(Listing).not_to have_received(:add_listing)
      end

      it 'outputs the unexpected response message' do
        expect { monitor.send(:monitor_search, search) }
          .to output(/No listings found or unexpected response format/).to_stdout
      end
    end

    context 'when API call raises an error' do
      let(:error_message) { 'Connection timeout' }

      before do
        allow(SociaVaultClient).to receive(:search)
          .and_raise(StandardError, error_message)
      end

      it 'catches the error and continues' do
        expect { monitor.send(:monitor_search, search) }.not_to raise_error
      end

      it 'outputs the error message' do
        expect { monitor.send(:monitor_search, search) }
          .to output(/✗ Error: #{error_message}/).to_stdout
      end

      it 'does not add listings' do
        monitor.send(:monitor_search, search)

        expect(Listing).not_to have_received(:add_listing)
      end
    end

    context 'when listings key is missing from response' do
      before do
        allow(SociaVaultClient).to receive(:search)
          .and_return({ 'data' => {} })
      end

      it 'outputs the unexpected response message' do
        expect { monitor.send(:monitor_search, search) }
          .to output(/No listings found or unexpected response format/).to_stdout
      end
    end

    context 'when data key is missing from response' do
      before do
        allow(SociaVaultClient).to receive(:search).and_return({})
      end

      it 'outputs the unexpected response message' do
        expect { monitor.send(:monitor_search, search) }
          .to output(/No listings found or unexpected response format/).to_stdout
      end
    end
  end

  describe '#send_alerts' do
    it 'retrieves unnotified and unsold listings' do
      monitor.send(:send_alerts)

      expect(Listing).to have_received(:unnotified_and_unsold)
    end

    it 'sends alerts via EmailService' do
      monitor.send(:send_alerts)

      expect(EmailService).to have_received(:send_alerts).with(unseen_listings)
    end

    it 'records an alert for each listing' do
      monitor.send(:send_alerts)

      unseen_listings.each do |listing|
        expect(Alert).to have_received(:record_alert).with(listing_id: listing['id'])
      end
    end

    it 'outputs the number of alerts sent' do
      expect { monitor.send(:send_alerts) }
        .to output(/📧 Sending alerts for #{unseen_listings.length}/).to_stdout
    end

    context 'when there are no unseen listings' do
      before do
        allow(Listing).to receive(:unnotified_and_unsold).and_return([])
      end

      it 'does not send alerts' do
        monitor.send(:send_alerts)

        expect(EmailService).not_to have_received(:send_alerts)
      end

      it 'does not record any alerts' do
        monitor.send(:send_alerts)

        expect(Alert).not_to have_received(:record_alert)
      end

      it 'outputs the no new listings message' do
        expect { monitor.send(:send_alerts) }
          .to output(/✓ No new listings to alert/).to_stdout
      end
    end
  end

  describe 'integration: full search cycle' do
    it 'completes a full search and alert cycle' do
      monitor.run_search

      search_config.each do |search|
        search_result['data']['listings'].each_value do |listing|
          expect(Listing).to have_received(:add_listing).with(listing, search[:query])
        end
      end

      expect(EmailService).to have_received(:send_alerts)
      unseen_listings.each do |listing|
        expect(Alert).to have_received(:record_alert).with(listing_id: listing['id'])
      end
    end

    it 'outputs complete sequence of messages' do
      expect { monitor.run_search }
        .to output(/🔍 Starting marketplace search|Searching:|Found|📧 Sending alerts/).to_stdout
    end
  end
end
