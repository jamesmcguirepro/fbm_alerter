# frozen_string_literal: true

require 'spec_helper'
require 'httparty'
require_relative '../../lib/socia_vault_client'

RSpec.describe SociaVaultClient do
  describe '.search' do
    let(:search_params) do
      {
        query: 'bike',
        lat: 40.7128,
        lng: -74.0060,
        min_price: 100,
        max_price: 500
      }
    end

    let(:success_response) do
      {
        'data' => {
          'listings' => {
            '0' => {
              'id' => '123456',
              'title' => 'Mountain Bike',
              'price' => { 'amount' => 250 },
              'location' => { 'display_name' => 'New York, NY' },
              'url' => 'https://facebook.com/marketplace/item/123456/',
              'primary_photo' => { 'url' => 'https://example.com/photo.jpg' }
            }
          }
        }
      }
    end

    before do
      allow(HTTParty).to receive(:get).and_return(double(code: 200, parsed_response: success_response, success?: true))
    end

    it 'calls API with correct endpoint' do
      described_class.search(**search_params)

      expect(HTTParty).to have_received(:get).with(
        'https://api.sociavault.com/v1/scrape/facebook-marketplace/search',
        anything
      )
    end

    it 'includes required parameters' do
      described_class.search(**search_params)

      expect(HTTParty).to have_received(:get).with(
        anything,
        hash_including(query: hash_including(query: 'bike', lat: 40.7128, lng: -74.0060))
      )
    end

    it 'includes optional price filters' do
      described_class.search(**search_params)

      expect(HTTParty).to have_received(:get).with(
        anything,
        hash_including(query: hash_including(min_price: 100, max_price: 500))
      )
    end

    it 'sets default sort order' do
      described_class.search(**search_params)

      expect(HTTParty).to have_received(:get).with(
        anything,
        hash_including(query: hash_including(sort_by: 'creation_time_descend'))
      )
    end

    it 'includes API key in headers' do
      described_class.search(**search_params)

      expect(HTTParty).to have_received(:get).with(
        anything,
        hash_including(headers: hash_including('X-API-Key' => 'sk_test_key'))
      )
    end

    it 'returns API response' do
      response = described_class.search(**search_params)
      expect(response).to eq(success_response)
    end

    it 'raises error on 400 Bad Request' do
      bad_response = double(code: 400, parsed_response: { 'error' => 'Invalid parameters' }, success?: false)
      allow(HTTParty).to receive(:get).and_return(bad_response)

      expect { described_class.search(**search_params) }.to raise_error(/Bad Request/)
    end

    it 'raises error on 401 Unauthorized' do
      auth_response = double(code: 401, parsed_response: { 'error' => 'Invalid API key' }, success?: false)
      allow(HTTParty).to receive(:get).and_return(auth_response)

      expect { described_class.search(**search_params) }.to raise_error(/Authentication Error/)
    end

    it 'raises error on 402 insufficient credits' do
      credit_response = double(
        code: 402,
        parsed_response: { 'required' => 1, 'available' => 0 },
        success?: false
      )
      allow(HTTParty).to receive(:get).and_return(credit_response)

      expect { described_class.search(**search_params) }.to raise_error(/Insufficient Credits/)
    end

    it 'raises error on 500 Server Error' do
      server_response = double(code: 500, parsed_response: { 'error' => 'Internal server error' }, success?: false)
      allow(HTTParty).to receive(:get).and_return(server_response)

      expect { described_class.search(**search_params) }.to raise_error(/Server Error/)
    end

    it 'includes radius_km in request' do
      described_class.search(**search_params, radius_km: 50)

      expect(HTTParty).to have_received(:get).with(
        anything,
        hash_including(query: hash_including(radius_km: 50))
      )
    end

    it 'includes condition filter when provided' do
      described_class.search(**search_params, condition: 'used_good')

      expect(HTTParty).to have_received(:get).with(
        anything,
        hash_including(query: hash_including(condition: 'used_good'))
      )
    end

    it 'includes delivery_method filter when provided' do
      described_class.search(**search_params, delivery_method: 'shipping')

      expect(HTTParty).to have_received(:get).with(
        anything,
        hash_including(query: hash_including(delivery_method: 'shipping'))
      )
    end

    it 'excludes optional params when not provided' do
      passed_opts = nil
      allow(HTTParty).to receive(:get) do |_url, opts|
        passed_opts = opts
        double(code: 200, parsed_response: success_response, success?: true)
      end

      described_class.search(**search_params)

      expect(passed_opts[:query]).not_to have_key(:condition)
      expect(passed_opts[:query]).not_to have_key(:delivery_method)
    end

    it 'uses default count when not provided' do
      described_class.search(**search_params)

      expect(HTTParty).to have_received(:get).with(
        anything,
        hash_including(query: hash_including(count: 24))
      )
    end

    it 'allows custom count' do
      described_class.search(**search_params, count: 50)

      expect(HTTParty).to have_received(:get).with(
        anything,
        hash_including(query: hash_including(count: 50))
      )
    end

    it 'sets timeout' do
      described_class.search(**search_params)

      expect(HTTParty).to have_received(:get).with(
        anything,
        hash_including(timeout: 30)
      )
    end
  end

  describe 'error handling' do
    let(:search_params) { { query: 'test', lat: 40.0, lng: -74.0 } }

    it 'raises error for unknown status code' do
      unknown_response = double(code: 999, parsed_response: { 'error' => 'Unknown error' }, success?: false)
      allow(HTTParty).to receive(:get).and_return(unknown_response)

      expect { described_class.search(**search_params) }.to raise_error(/API Error/)
    end

    it 'includes response code in error message' do
      error_response = double(code: 500, parsed_response: { 'error' => 'Server error' }, success?: false)
      allow(HTTParty).to receive(:get).and_return(error_response)

      expect { described_class.search(**search_params) }.to raise_error(/500/)
    end
  end
end
