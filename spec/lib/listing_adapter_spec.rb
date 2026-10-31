# frozen_string_literal: true

require 'spec_helper'
require_relative '../../lib/listing_adapter'

RSpec.describe ListingAdapter do
  describe '.from_socia_vault' do
    let(:raw) do
      {
        'id' => 'fb-12345',
        'title' => '2022 Husqvarna TE 300',
        'price' => { 'amount' => 3500.0 },
        'location' => { 'display_name' => 'Austin, TX' },
        'url' => 'https://facebook.com/marketplace/item/12345',
        'primary_photo' => { 'url' => 'https://example.com/photo.jpg' },
        'creation_time' => '2026-10-18T10:00:00.000Z',
        'is_sold' => false
      }
    end

    it 'maps all SociaVault fields to ListingObject' do
      result = described_class.from_socia_vault(raw)

      expect(result).to be_a(ListingObject)
      expect(result.listing_id).to eq('fb-12345')
      expect(result.title).to eq('2022 Husqvarna TE 300')
      expect(result.price).to eq(3500.0)
      expect(result.location).to eq('Austin, TX')
      expect(result.url).to eq('https://facebook.com/marketplace/item/12345')
      expect(result.image_url).to eq('https://example.com/photo.jpg')
      expect(result.listed_at).to eq(Time.utc(2026, 10, 18, 10, 0, 0))
      expect(result.is_sold).to be(false)
    end

    it 'handles missing fields gracefully' do
      partial = { 'id' => 'fb-99', 'title' => 'Bare Listing' }
      result = described_class.from_socia_vault(partial)

      expect(result.listing_id).to eq('fb-99')
      expect(result.title).to eq('Bare Listing')
      expect(result.price).to be_nil
      expect(result.location).to be_nil
      expect(result.url).to be_nil
      expect(result.image_url).to be_nil
      expect(result.is_sold).to be_nil
    end
  end
end
