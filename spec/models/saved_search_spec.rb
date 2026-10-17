# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SavedSearch, type: :model do
  describe '.add_search' do
    let(:search_object) do
      SearchObject.new(
        id: nil,
        query: 'bike',
        lat: 40.7128,
        long: -74.0060,
        min_price: 100,
        max_price: 500,
        radius_km: 25,
        condition: 'used_good',
        delivery_method: 'shipping'
      )
    end

    it 'creates a saved search from a search object' do
      expect {
        described_class.add_search(search_object:, email: 'owner@example.com')
      }.to change(described_class, :count).by(1)
    end

    it 'sets all attributes correctly' do
      described_class.add_search(search_object:, email: 'owner@example.com')
      search = described_class.first

      expect(search.query).to eq('bike')
      expect(search.lat).to eq(40.7128)
      expect(search.long).to eq(-74.0060)
      expect(search.min_price).to eq(100)
      expect(search.max_price).to eq(500)
      expect(search.radius_km).to eq(25)
      expect(search.condition).to eq('used_good')
      expect(search.delivery_method).to eq('shipping')
      expect(search.email).to eq('owner@example.com')
    end
  end

  describe '#print_search' do
    it 'prints search details' do
      search = described_class.create!(
        query: 'bike',
        lat: 40.7128,
        long: -74.0060,
        min_price: 100,
        max_price: 500,
        email: 'owner@example.com'
      )

      expect { search.print_search }.to output(/ID: #{search.id}/).to_stdout
    end
  end

  describe 'coordinate validations' do
    let(:attrs) { { query: 'bike', email: 'owner@example.com' } }

    it 'is valid with in-range coordinates' do
      expect(described_class.new(attrs.merge(lat: 40.7128, long: -74.0060))).to be_valid
    end

    it 'is invalid without a latitude' do
      search = described_class.new(attrs.merge(long: -74.0060))
      expect(search).not_to be_valid
      expect(search.errors[:lat]).to be_present
    end

    it 'is invalid without a longitude' do
      search = described_class.new(attrs.merge(lat: 40.7128))
      expect(search).not_to be_valid
      expect(search.errors[:long]).to be_present
    end

    it 'rejects a latitude outside -90..90' do
      expect(described_class.new(attrs.merge(lat: 91, long: 0))).not_to be_valid
    end

    it 'rejects a longitude outside -180..180' do
      expect(described_class.new(attrs.merge(lat: 0, long: -11971922006451092))).not_to be_valid
    end
  end

  describe '#valid_coordinates?' do
    it 'is true for in-range coordinates' do
      expect(described_class.new(lat: 40.7128, long: -74.0060)).to be_valid_coordinates
    end

    it 'is false when coordinates are missing' do
      expect(described_class.new(lat: nil, long: nil)).not_to be_valid_coordinates
    end

    it 'is false when coordinates are out of range' do
      expect(described_class.new(lat: 40.7128, long: -11971922006451092)).not_to be_valid_coordinates
    end
  end

  describe 'radius validation' do
    let(:attrs) { { query: 'bike', lat: 40.7128, long: -74.0060, email: 'owner@example.com' } }

    it 'defaults to 65 km' do
      expect(described_class.new(attrs).radius_km).to eq(65)
    end

    it 'accepts a radius within 5..1000' do
      expect(described_class.new(attrs.merge(radius_km: 25))).to be_valid
    end

    it 'rejects a radius below 5 km' do
      search = described_class.new(attrs.merge(radius_km: 4))
      expect(search).not_to be_valid
      expect(search.errors[:radius_km]).to be_present
    end

    it 'rejects a radius above 1000 km' do
      expect(described_class.new(attrs.merge(radius_km: 1001))).not_to be_valid
    end
  end

  describe '#resolve_location! / #location_label' do
    let(:attrs) { { query: 'bike', lat: 40.7128, long: -74.0060, email: 'owner@example.com' } }

    def stub_lookup(city: 'Austin', state: 'Texas')
      stub_request(:get, %r{nominatim\.openstreetmap\.org/reverse}).to_return(
        status: 200,
        body: { 'address' => { 'city' => city, 'state' => state } }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
    end

    it 'resolves and caches the place name' do
      stub_lookup
      search = described_class.create!(attrs)

      expect(search.resolve_location!).to eq('Austin, Texas')
      expect(search.reload.resolved_location).to eq('Austin, Texas')
      expect(search.location_label).to eq('Austin, Texas')
    end

    it 'uses the cache and makes no request when a name is present' do
      search = described_class.create!(attrs.merge(resolved_location: 'Cached, CA'))

      expect(search.resolve_location!).to eq('Cached, CA')
      expect(a_request(:get, %r{nominatim})).not_to have_been_made
    end

    it 'returns nil and makes no request without valid coordinates' do
      search = described_class.new(query: 'bike')

      expect(search.resolve_location!).to be_nil
      expect(a_request(:get, %r{nominatim})).not_to have_been_made
    end

    it 'falls back to raw coordinates for display when unresolved' do
      expect(described_class.new(attrs).location_label).to eq('40.7128, -74.006')
    end
  end

  describe 'coordinate precision' do
    it 'rounds coordinates to 4 decimals on save' do
      search = described_class.create!(
        query: 'bike', lat: 34.43295451090155, long: -119.71922006451092,
        email: 'owner@example.com'
      )

      expect(search.lat.to_f).to eq(34.433)
      expect(search.long.to_f).to eq(-119.7192)
    end
  end

  describe 'coordinate changes' do
    it 'clears a stale cached place name' do
      search = described_class.create!(
        query: 'bike', lat: 40.7128, long: -74.0060, email: 'owner@example.com',
        resolved_location: 'New York, New York'
      )

      search.update!(lat: 34.0)

      expect(search.reload.resolved_location).to be_nil
    end
  end
end
