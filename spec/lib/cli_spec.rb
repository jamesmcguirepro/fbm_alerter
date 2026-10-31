# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CLI do
  let(:cli) { described_class.new }
  let(:location) { { lat: 40.7128, long: -74.0060, resolved_location: nil } }

  describe '#search_object' do
    it 'maps the radius option to radius_mi' do
      options = {
        query: 'bike',
        radius: 25,
        min: 100,
        max: 500,
        cond: 'used_good',
        del: 'shipping'
      }

      search_object = cli.send(:search_object, options:, location:)

      expect(search_object.radius_mi).to eq(25)
      expect(search_object.lat).to eq(40.7128)
      expect(search_object.long).to eq(-74.0060)
      expect(search_object.condition).to eq('used_good')
      expect(search_object.delivery_method).to eq('shipping')
    end

    it 'defaults radius_mi to nil when not provided' do
      options = { query: 'bike', min: 100, max: 500 }

      search_object = cli.send(:search_object, options:, location:)

      expect(search_object.radius_mi).to be_nil
    end
  end

  describe '#resolve_location' do
    def stub_city_lookup
      stub_request(:get, %r{nominatim\.openstreetmap\.org/search})
        .with(query: hash_including(q: /austin.*texas/i))
        .to_return(
          status: 200,
          body: [
            {
              'lat' => '30.2672',
              'lon' => '-97.7431',
              'display_name' => 'Austin, Travis County, Texas, United States',
              'address' => { 'city' => 'Austin', 'state' => 'Texas', 'country' => 'United States' }
            }
          ].to_json,
          headers: { 'Content-Type' => 'application/json' }
        )
    end

    it 'geocodes a city into coordinates and a cached place name' do
      stub_city_lookup

      resolved = cli.send(:resolve_location, { city: 'Austin, TX' })

      expect(resolved[:lat]).to eq(30.2672)
      expect(resolved[:long]).to eq(-97.7431)
      expect(resolved[:resolved_location]).to eq('Austin, Texas')
    end

    it 'uses explicit coordinates without calling Nominatim' do
      resolved = cli.send(:resolve_location, { lat: '40.7128', long: '-74.0060' })

      expect(resolved[:lat]).to eq('40.7128')
      expect(resolved[:long]).to eq('-74.0060')
      expect(resolved[:resolved_location]).to be_nil
      expect(a_request(:get, %r{nominatim})).not_to have_been_made
    end

    it 'requires either --city or both coordinates' do
      expect { cli.send(:resolve_location, {}) }
        .to raise_error(Thor::Error, /Provide --city, or both --lat and --long/)
    end

    it 'rejects mixing --city with explicit coordinates' do
      expect { cli.send(:resolve_location, { city: 'Austin, TX', lat: '1', long: '2' }) }
        .to raise_error(Thor::Error, /not both/)
    end

    it 'raises when the city cannot be found' do
      stub_request(:get, %r{nominatim\.openstreetmap\.org/search}).to_return(status: 200, body: '[]')

      expect { cli.send(:resolve_location, { city: 'Nowhere' }) }
        .to raise_error(Thor::Error, /Could not find location/)
    end
  end
end
