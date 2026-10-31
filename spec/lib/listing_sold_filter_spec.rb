# frozen_string_literal: true

require 'spec_helper'
require_relative '../../lib/listing_sold_filter'

RSpec.describe ListingSoldFilter do
  let(:filter) { described_class.new }
  let(:search_object) { nil }

  def make_listing(is_sold:)
    ListingObject.new(
      listing_id: '1', title: 'Test', price: 100, location: nil, url: 'http://x',
      image_url: nil, search_query: 'test', listed_at: Time.current,
      first_seen_at: nil, last_seen_at: nil, is_sold:
    )
  end

  describe '#filter' do
    it 'drops sold listings' do
      listing = make_listing(is_sold: true)

      expect(filter.filter(listing, search_object)).to be(false)
    end

    it 'keeps unsold listings' do
      listing = make_listing(is_sold: false)

      expect(filter.filter(listing, search_object)).to be(true)
    end

    it 'keeps listings without an is_sold flag' do
      listing = make_listing(is_sold: nil)

      expect(filter.filter(listing, search_object)).to be(true)
    end
  end
end
