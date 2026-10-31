# frozen_string_literal: true

require 'spec_helper'
require_relative '../../lib/distance'

RSpec.describe Distance do
  describe '.miles_to_km' do
    it 'converts miles to kilometres' do
      expect(described_class.miles_to_km(40)).to eq(64.37376)
    end

    it 'returns nil for nil' do
      expect(described_class.miles_to_km(nil)).to be_nil
    end

    it 'handles zero' do
      expect(described_class.miles_to_km(0)).to eq(0.0)
    end
  end

  describe '.haversine' do
    it 'returns 0 for the same coordinates' do
      expect(described_class.haversine(30.2672, -97.7431, 30.2672, -97.7431)).to eq(0.0)
    end

    it 'returns approximately the distance between Austin and Dallas' do
      # Austin to Dallas is about 290 km
      result = described_class.haversine(30.2672, -97.7431, 32.7767, -96.7970)
      expect(result).to be_within(5).of(290)
    end

    it 'returns nil when any coordinate is nil' do
      expect(described_class.haversine(30.2672, nil, 32.7767, -96.7970)).to be_nil
      expect(described_class.haversine(nil, -97.7431, 32.7767, -96.7970)).to be_nil
    end
  end
end
