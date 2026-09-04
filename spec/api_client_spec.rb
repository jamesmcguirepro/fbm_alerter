# frozen_string_literal: true

require 'spec_helper'
require 'httparty'
require_relative '../lib/api_client'

RSpec.describe APIClient do
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

      call_args = HTTParty.call_args
      query_params = call_args[1][:query]

      expect(query_params[:query]).to eq('bike')
      expect(query_params[:lat]).to eq(40.7128)
      expect(query_params[:lng]).to eq(-74.0060)
    end

    it 'includes optional price filters' do
      described_class.search(**search_params)

      call_args = HTTParty.call_args
      query_params = call_args[1][:query]

      expect(query_params[:min_price]).to eq(100)
      expect(query_params[:max_price]).to eq(500)
    end

    it 'sets default sort order' do
      described_class.search(**search_params)

      call_args = HTTParty.call_args
      query_params = call_args[1][:query]

      expect(query_params[:sort_by]).to eq('creation_time_descend')
    end

    it 'includes API key in headers' do
      described_class.search(**search_params)

      call_args = HTTParty.call_args
      headers = call_args[1][:headers]

      expect(headers['X-API-Key']).to eq('sk_test_key')
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

      call_args = HTTParty.call_args
      expect(call_args[1][:query][:radius_km]).to eq(50)
    end

    it 'includes condition filter when provided' do
      described_class.search(**search_params, condition: 'used_good')

      call_args = HTTParty.call_args
      expect(call_args[1][:query][:condition]).to eq('used_good')
    end

    it 'includes delivery_method filter when provided' do
      described_class.search(**search_params, delivery_method: 'shipping')

      call_args = HTTParty.call_args
      expect(call_args[1][:query][:delivery_method]).to eq('shipping')
    end

    it 'excludes optional params when not provided' do
      described_class.search(**search_params)

      call_args = HTTParty.call_args
      query_params = call_args[1][:query]

      expect(query_params.key?(:condition)).to be false
      expect(query_params.key?(:delivery_method)).to be false
    end

    it 'uses default count when not provided' do
      described_class.search(**search_params)

      call_args = HTTParty.call_args
      expect(call_args[1][:query][:count]).to eq(24)
    end

    it 'allows custom count' do
      described_class.search(**search_params, count: 50)

      call_args = HTTParty.call_args
      expect(call_args[1][:query][:count]).to eq(50)
    end

    it 'sets timeout' do
      described_class.search(**search_params)

      call_args = HTTParty.call_args
      expect(call_args[1][:timeout]).to eq(30)
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
