# frozen_string_literal: true

require 'spec_helper'
require_relative '../../lib/geocode_cache'

RSpec.describe GeocodeCache do
  describe '.read' do
    it 'returns coordinates for a cached entry' do
      described_class.write('austin, texas', { lat: 30.2672, lon: -97.7431 })

      expect(described_class.read('austin, texas')).to eq(lat: 30.2672, lon: -97.7431)
    end

    it 'returns nil for a non-existent entry' do
      expect(described_class.read('nowhere, land')).to be_nil
    end

    it 'returns nil for a blank key' do
      expect(described_class.read('')).to be_nil
      expect(described_class.read(nil)).to be_nil
    end

    it 'returns nil for an expired entry' do
      described_class.write('austin, texas', { lat: 30.2672, lon: -97.7431 })
      entry = GeocodeCacheEntry.find_by(query: 'austin, texas', primary: true)
      entry.update!(fetched_at: (GeocodeCache::TTL + 1.day).ago)

      expect(described_class.read('austin, texas')).to be_nil
    end
  end

  describe '.write' do
    it 'creates a new cache entry' do
      described_class.write('dallas, texas', { lat: 32.7767, lon: -96.7970 })

      expect(GeocodeCacheEntry.where(query: 'dallas, texas', primary: true).count).to eq(1)
    end

    it 'updates an existing entry' do
      described_class.write('austin, texas', { lat: 30.2672, lon: -97.7431 })
      described_class.write('austin, texas', { lat: 30.27, lon: -97.75 })

      result = described_class.read('austin, texas')
      expect(result[:lat]).to eq(30.27)
      expect(result[:lon]).to eq(-97.75)
    end

    it 'does not write nil or empty values' do
      described_class.write('austin, texas', nil)
      described_class.write('austin, texas', { lat: nil, lon: -97.7431 })
      described_class.write('', { lat: 30.2672, lon: -97.7431 })

      expect(GeocodeCacheEntry.where(query: 'austin, texas', primary: true).count).to eq(0)
    end
  end
end
