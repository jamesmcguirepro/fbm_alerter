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
end
