# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Geocoder do
  let(:search_url) { %r{nominatim\.openstreetmap\.org/search} }
  let(:reverse_url) { %r{nominatim\.openstreetmap\.org/reverse} }

  let(:austin_result) do
    {
      'lat' => '30.2672',
      'lon' => '-97.7431',
      'display_name' => 'Austin, Travis County, Texas, United States',
      'address' => { 'city' => 'Austin', 'state' => 'Texas', 'country' => 'United States' }
    }
  end

  describe '.search' do
    it 'returns places with a compact name and coordinates' do
      stub_request(:get, search_url)
        .with(query: hash_including(q: /austin.*texas/i))
        .to_return(status: 200, body: [austin_result].to_json,
                   headers: { 'Content-Type' => 'application/json' })

      places = described_class.search(query: 'Austin, TX')

      expect(places.length).to eq(1)
      expect(places.first.name).to eq('Austin, Texas')
      expect(places.first.display_name).to eq('Austin, Travis County, Texas, United States')
      expect(places.first.lat).to eq(30.2672)
      expect(places.first.long).to eq(-97.7431)
    end

    it 'sends the usage-policy headers and parameters' do
      stub_request(:get, search_url).to_return(status: 200, body: '[]')

      described_class.search(query: '78701')

      expect(
        a_request(:get, search_url).with(
          query: hash_including(format: 'jsonv2', q: '78701', addressdetails: '1', limit: '5'),
          headers: { 'User-Agent' => Geocoder::USER_AGENT, 'Accept-Language' => 'en' }
        )
      ).to have_been_made.once
    end

    it 'does not call Nominatim for a blank query' do
      expect(described_class.search(query: '  ')).to eq([])
      expect(a_request(:get, search_url)).not_to have_been_made
    end

    it 'returns an empty list on a non-200 response' do
      stub_request(:get, search_url).to_return(status: 503, body: 'unavailable')

      expect(described_class.search(query: 'Austin')).to eq([])
    end

    it 'returns an empty list on a network error' do
      stub_request(:get, search_url).to_timeout

      expect(described_class.search(query: 'Austin')).to eq([])
    end

    it 'ignores malformed results' do
      stub_request(:get, search_url)
        .to_return(status: 200, body: [{ 'display_name' => 'No coordinates' }, 'nonsense'].to_json,
                   headers: { 'Content-Type' => 'application/json' })

      expect(described_class.search(query: 'Austin')).to eq([])
    end

    it 'caches identical lookups instead of requesting again' do
      stub_request(:get, search_url)
        .to_return(status: 200, body: [austin_result].to_json,
                   headers: { 'Content-Type' => 'application/json' })

      2.times { described_class.search(query: 'Austin, TX') }

      expect(a_request(:get, search_url)).to have_been_made.once
      expect(GeocodeCacheEntry.where(primary: true).count).to eq(1)
    end

    it 'treats differently-cased or spaced queries as the same cache entry' do
      stub_request(:get, search_url)
        .to_return(status: 200, body: [austin_result].to_json,
                   headers: { 'Content-Type' => 'application/json' })

      described_class.search(query: 'Austin, TX')
      described_class.search(query: '  austin,   tx  ')

      expect(a_request(:get, search_url)).to have_been_made.once
    end

    it 're-fetches an expired cache entry' do
      GeocodeCache.write('austin, texas', { lat: 30.2672, lon: -97.7431 })
      # Manually backdate the entry to simulate expiry
      entry = GeocodeCacheEntry.find_by(query: 'austin, texas', primary: true)
      entry.update!(fetched_at: (Geocoder::CACHE_TTL + 1.day).ago)

      stub_request(:get, search_url)
        .to_return(status: 200, body: [austin_result].to_json,
                   headers: { 'Content-Type' => 'application/json' })

      places = described_class.search(query: 'Austin, TX')

      expect(a_request(:get, search_url)).to have_been_made.once
      expect(places.first.name).to eq('Austin, Texas')
    end
  end

  describe '.reverse' do
    let(:reverse_body) do
      {
        'display_name' => 'Austin, Travis County, Texas, United States',
        'address' => { 'city' => 'Austin', 'state' => 'Texas', 'country' => 'United States' }
      }
    end

    it 'returns a place name for coordinates' do
      stub_request(:get, reverse_url)
        .with(query: hash_including(lat: '30.2672', lon: '-97.7431', zoom: '10'))
        .to_return(status: 200, body: reverse_body.to_json,
                   headers: { 'Content-Type' => 'application/json' })

      expect(described_class.reverse(lat: 30.2672, long: -97.7431)).to eq('Austin, Texas')
    end

    it 'returns nil when a coordinate is missing' do
      expect(described_class.reverse(lat: nil, long: -97.7431)).to be_nil
      expect(described_class.reverse(lat: 30.2672, long: nil)).to be_nil
      expect(a_request(:get, reverse_url)).not_to have_been_made
    end

    it 'returns nil on a non-200 response' do
      stub_request(:get, reverse_url).to_return(status: 429, body: 'slow down')

      expect(described_class.reverse(lat: 30.2672, long: -97.7431)).to be_nil
    end

    it 'returns nil when Nominatim returns an error object' do
      stub_request(:get, reverse_url)
        .to_return(status: 200, body: { 'error' => 'Unable to geocode' }.to_json,
                   headers: { 'Content-Type' => 'application/json' })

      expect(described_class.reverse(lat: 30.2672, long: -97.7431)).to be_nil
      expect(GeocodeCacheEntry.count).to eq(0)
    end
  end

  describe '.normalize_location' do
    it 'expands state abbreviations' do
      expect(described_class.normalize_location('Austin, TX')).to eq('Austin, Texas')
    end

    it 'leaves full state names unchanged' do
      expect(described_class.normalize_location('Austin, Texas')).to eq('Austin, Texas')
    end

    it 'normalizes case' do
      expect(described_class.normalize_location('dallas, tx')).to eq('Dallas, Texas')
    end

    it 'handles single-word locations' do
      expect(described_class.normalize_location('Denver')).to eq('Denver')
    end

    it 'handles DC abbreviation' do
      expect(described_class.normalize_location('Washington, DC')).to eq('Washington, District of Columbia')
    end
  end
end
