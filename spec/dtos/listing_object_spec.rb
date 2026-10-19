# frozen_string_literal: true

require 'spec_helper'
require_relative '../../dtos/listing_object'

RSpec.describe ListingObject do
  describe '.from_listing_response' do
    let(:response) do
      {
        'id' => '123456',
        'title' => 'Husqvarna TE 300',
        'price' => { 'amount' => 6700 },
        'location' => { 'display_name' => 'Santa Barbara, CA' },
        'url' => 'https://facebook.com/marketplace/item/123456/',
        'primary_photo' => { 'url' => 'https://example.com/photo.jpg' },
        'creation_time' => '2026-10-16T20:08:38.000Z',
        'is_sold' => false
      }
    end

    it 'maps the listing fields' do
      object = described_class.from_listing_response(response:, search_query: 'husqvarna te 300')

      expect(object.listing_id).to eq('123456')
      expect(object.title).to eq('Husqvarna TE 300')
      expect(object.price).to eq(6700)
      expect(object.location).to eq('Santa Barbara, CA')
      expect(object.url).to eq('https://facebook.com/marketplace/item/123456/')
      expect(object.image_url).to eq('https://example.com/photo.jpg')
      expect(object.search_query).to eq('husqvarna te 300')
      expect(object.is_sold).to be(false)
    end

    it 'takes the listed time from creation_time' do
      object = described_class.from_listing_response(response:)

      expect(object.listed_at).to eq(Time.utc(2026, 10, 16, 20, 8, 38))
    end

    it 'leaves the listed time nil when creation_time is absent' do
      object = described_class.from_listing_response(response: response.except('creation_time'))

      expect(object.listed_at).to be_nil
    end

    it 'leaves the listed time nil when creation_time is null' do
      object = described_class.from_listing_response(response: response.merge('creation_time' => nil))

      expect(object.listed_at).to be_nil
    end

    it 'leaves the listed time nil when creation_time cannot be parsed' do
      object = described_class.from_listing_response(response: response.merge('creation_time' => '3 days ago'))

      expect(object.listed_at).to be_nil
    end
  end
end
