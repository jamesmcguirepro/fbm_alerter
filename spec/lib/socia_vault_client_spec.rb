# frozen_string_literal: true

require 'spec_helper'
require 'httparty'
require_relative '../../lib/socia_vault_client'

RSpec.describe SociaVaultClient do
  let(:search_object) do
    SearchObject.new(
      id: nil,
      query: 'bike',
      lat: 40.7128,
      long: -74.0060,
      min_price: 100,
      max_price: 500,
      radius_mi: 25,
      condition: nil,
      delivery_method: nil
    )
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

  describe '.search_page' do
    it 'calls API with correct endpoint' do
      described_class.search_page(search_object:)

      expect(HTTParty).to have_received(:get).with(
        'https://api.sociavault.com/v1/scrape/facebook-marketplace/search',
        anything
      )
    end

    it 'includes required parameters' do
      described_class.search_page(search_object:)

      expect(HTTParty).to have_received(:get).with(
        anything,
        hash_including(query: hash_including(query: 'bike', lat: 40.7128, lng: -74.0060))
      )
    end

    it 'includes optional price filters' do
      described_class.search_page(search_object:)

      expect(HTTParty).to have_received(:get).with(
        anything,
        hash_including(query: hash_including(min_price: 100, max_price: 500))
      )
    end

    it 'limits results to the recency window' do
      described_class.search_page(search_object:)

      expect(HTTParty).to have_received(:get).with(
        anything,
        hash_including(query: hash_including(date_listed: 'last_7_days'))
      )
    end

    it 'uses the window given by DATE_LISTED' do
      ENV['DATE_LISTED'] = 'last_30_days'

      described_class.search_page(search_object:)

      expect(HTTParty).to have_received(:get).with(
        anything,
        hash_including(query: hash_including(date_listed: 'last_30_days'))
      )
    ensure
      ENV.delete('DATE_LISTED')
    end

    it 'does not send a sort order' do
      # creation_time_descend makes Facebook ignore the query and return the
      # newest listings anywhere, not the newest matches.
      described_class.search_page(search_object:)

      expect(HTTParty).to have_received(:get).with(
        anything,
        hash_including(query: hash_not_including(:sort_by))
      )
    end

    it 'includes API key in headers' do
      described_class.search_page(search_object:)

      expect(HTTParty).to have_received(:get).with(
        anything,
        hash_including(headers: hash_including('X-API-Key' => 'sk_test_key'))
      )
    end

    it 'returns the listings for the page' do
      result = described_class.search_page(search_object:)

      expect(result[:listings].map { |l| l['id'] }).to eq(['123456'])
      expect(result[:listings].first['title']).to eq('Mountain Bike')
    end

    it 'returns a nil cursor and assumes another page when the flag is missing' do
      result = described_class.search_page(search_object:)

      expect(result[:cursor]).to be_nil
      expect(result[:has_next_page]).to be(true)
    end

    it 'returns the cursor and next-page flag when present' do
      allow(HTTParty).to receive(:get).and_return(
        double(
          code: 200,
          parsed_response: {
            'data' => {
              'listings' => { '1' => { 'id' => '1', 'title' => 'Bike' } },
              'next_cursor' => 'page-2',
              'has_next_page' => false
            }
          },
          success?: true
        )
      )

      result = described_class.search_page(search_object:)

      expect(result[:cursor]).to eq('page-2')
      expect(result[:has_next_page]).to be(false)
    end

    it 'sends the cursor when given' do
      described_class.search_page(search_object:, cursor: 'page-2')

      expect(HTTParty).to have_received(:get).with(
        anything,
        hash_including(query: hash_including(cursor: 'page-2'))
      )
    end

    it 'accepts listings returned as an array' do
      allow(HTTParty).to receive(:get).and_return(
        double(
          code: 200,
          parsed_response: { 'data' => { 'listings' => [{ 'id' => '1', 'title' => 'Bike' }] } },
          success?: true
        )
      )

      expect(described_class.search_page(search_object:)[:listings].length).to eq(1)
    end

    it 'raises error on 400 Bad Request' do
      bad_response = double(code: 400, parsed_response: { 'error' => 'Invalid parameters' }, success?: false)
      allow(HTTParty).to receive(:get).and_return(bad_response)

      expect { described_class.search_page(search_object:) }.to raise_error(/Bad Request/)
    end

    it 'raises error on 401 Unauthorized' do
      auth_response = double(code: 401, parsed_response: { 'error' => 'Invalid API key' }, success?: false)
      allow(HTTParty).to receive(:get).and_return(auth_response)

      expect { described_class.search_page(search_object:) }.to raise_error(/Authentication Error/)
    end

    it 'raises error on 402 insufficient credits' do
      credit_response = double(
        code: 402,
        parsed_response: { 'required' => 1, 'available' => 0 },
        success?: false
      )
      allow(HTTParty).to receive(:get).and_return(credit_response)

      expect { described_class.search_page(search_object:) }.to raise_error(/Insufficient Credits/)
    end

    it 'raises error on 500 Server Error' do
      server_response = double(code: 500, parsed_response: { 'error' => 'Internal server error' }, success?: false)
      allow(HTTParty).to receive(:get).and_return(server_response)

      expect { described_class.search_page(search_object:) }.to raise_error(/Server Error/)
    end

    it 'converts miles to radius_km in the request' do
      described_class.search_page(search_object:)

      expect(HTTParty).to have_received(:get).with(
        anything,
        hash_including(query: hash_including(radius_km: 40))
      )
    end

    it 'includes condition filter when provided' do
      search_object = build_search_object(condition: 'used_good')

      described_class.search_page(search_object:)

      expect(HTTParty).to have_received(:get).with(
        anything,
        hash_including(query: hash_including(condition: 'used_good'))
      )
    end

    it 'includes delivery_method filter when provided' do
      search_object = build_search_object(delivery_method: 'shipping')

      described_class.search_page(search_object:)

      expect(HTTParty).to have_received(:get).with(
        anything,
        hash_including(query: hash_including(delivery_method: 'shipping'))
      )
    end

    it 'excludes optional params when not provided' do
      search_object = build_search_object(min_price: nil, max_price: nil)
      passed_opts = nil
      allow(HTTParty).to receive(:get) do |_url, opts|
        passed_opts = opts
        double(code: 200, parsed_response: success_response, success?: true)
      end

      described_class.search_page(search_object:)

      expect(passed_opts[:query]).not_to have_key(:condition)
      expect(passed_opts[:query]).not_to have_key(:delivery_method)
      expect(passed_opts[:query]).not_to have_key(:min_price)
      expect(passed_opts[:query]).not_to have_key(:max_price)
    end

    it 'uses default count' do
      described_class.search_page(search_object:)

      expect(HTTParty).to have_received(:get).with(
        anything,
        hash_including(query: hash_including(count: 100))
      )
    end

    it 'yields once per request, so callers can account for the credit spent' do
      requests = 0
      described_class.search_page(search_object:) { requests += 1 }

      expect(requests).to eq(1)
    end

    it 'sets timeout' do
      described_class.search_page(search_object:)

      expect(HTTParty).to have_received(:get).with(
        anything,
        hash_including(timeout: 30)
      )
    end
  end

  describe 'error handling' do
    it 'raises error for unknown status code' do
      unknown_response = double(code: 999, parsed_response: { 'error' => 'Unknown error' }, success?: false)
      allow(HTTParty).to receive(:get).and_return(unknown_response)

      expect { described_class.search_page(search_object:) }.to raise_error(/API Error/)
    end

    it 'includes response code in error message' do
      error_response = double(code: 500, parsed_response: { 'error' => 'Server error' }, success?: false)
      allow(HTTParty).to receive(:get).and_return(error_response)

      expect { described_class.search_page(search_object:) }.to raise_error(/500/)
    end

    context 'with non-JSON error body' do
      it 'raises a meaningful error on 400 instead of NoMethodError' do
        html_body = '<html><body>400 Bad Request</body></html>'
        bad_response = double(code: 400, parsed_response: html_body, body: html_body, success?: false)
        allow(HTTParty).to receive(:get).and_return(bad_response)

        expect { described_class.search_page(search_object:) }
          .to raise_error(/Bad Request.*400 Bad Request/)
      end

      it 'raises a meaningful error on 500 instead of NoMethodError' do
        html_body = '<html><body>500 Internal Server Error</body></html>'
        server_response = double(code: 500, parsed_response: html_body, body: html_body, success?: false)
        allow(HTTParty).to receive(:get).and_return(server_response)

        expect { described_class.search_page(search_object:) }
          .to raise_error(/500 Server Error.*500 Internal Server Error/)
      end

      it 'raises a meaningful error on unknown status code instead of NoMethodError' do
        plain_body = 'Something went wrong'
        unknown_response = double(code: 502, parsed_response: plain_body, body: plain_body, success?: false)
        allow(HTTParty).to receive(:get).and_return(unknown_response)

        expect { described_class.search_page(search_object:) }
          .to raise_error(/API Error \(502\).*Something went wrong/)
      end

      it 'falls back to response body when 402 has no structured JSON' do
        plain_body = 'Insufficient credits'
        credit_response = double(code: 402, parsed_response: plain_body, body: plain_body, success?: false)
        allow(HTTParty).to receive(:get).and_return(credit_response)

        expect { described_class.search_page(search_object:) }
          .to raise_error(/Insufficient Credits: Insufficient credits/)
      end
    end
  end

  describe '.search_page in dry run' do
    before { allow(Config).to receive(:dry_run?).and_return(true) }

    it 'never touches the network' do
      expect(HTTParty).not_to receive(:get)

      requested = false
      result = described_class.search_page(search_object:) { requested = true }

      expect(result).to eq(listings: [], cursor: nil, has_next_page: false)
      expect(requested).to be(false)
    end

    it 'still reads the credit balance, because that call is free' do
      allow(HTTParty).to receive(:get).and_return(
        double(code: 200, parsed_response: { 'credits' => 950 }, success?: true)
      )

      expect(described_class.credits['credits']).to eq(950)
      expect(HTTParty).to have_received(:get).with(
        'https://api.sociavault.com/v1/credits', anything
      )
    end
  end

  describe '.credits' do
    let(:balance_response) do
      { 'credits' => 950, 'subscriptionStatus' => 'active', 'subscriptionId' => nil }
    end

    before do
      allow(HTTParty).to receive(:get).and_return(
        double(code: 200, parsed_response: balance_response, success?: true)
      )
    end

    it 'calls the credits endpoint with the API key' do
      described_class.credits

      expect(HTTParty).to have_received(:get).with(
        'https://api.sociavault.com/v1/credits',
        hash_including(headers: hash_including('X-API-Key' => 'sk_test_key'))
      )
    end

    it 'returns the remaining balance' do
      expect(described_class.credits['credits']).to eq(950)
    end

    it 'raises when the key is rejected' do
      allow(HTTParty).to receive(:get).and_return(
        double(code: 401, parsed_response: { 'error' => 'Invalid API key' }, success?: false)
      )

      expect { described_class.credits }.to raise_error(/Authentication Error/)
    end
  end

  def build_search_object(**overrides)
    defaults = {
      id: nil,
      query: 'bike',
      lat: 40.7128,
      long: -74.0060,
      min_price: 100,
      max_price: 500,
      radius_mi: 25,
      condition: nil,
      delivery_method: nil
    }

    SearchObject.new(**defaults.merge(overrides))
  end
end
