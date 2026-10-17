# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CLI do
  describe '#search_object' do
    let(:cli) { described_class.new }

    it 'maps radius option to radius_km' do
      options = {
        query: 'bike',
        lat: 40.7128,
        long: -74.0060,
        radius: 25,
        min: 100,
        max: 500,
        cond: 'used_good',
        del: 'shipping'
      }

      search_object = cli.send(:search_object, options:)

      expect(search_object.radius_km).to eq(25)
      expect(search_object.condition).to eq('used_good')
      expect(search_object.delivery_method).to eq('shipping')
    end

    it 'defaults radius_km to nil when not provided' do
      options = {
        query: 'bike',
        lat: 40.7128,
        long: -74.0060,
        min: 100,
        max: 500
      }

      search_object = cli.send(:search_object, options:)

      expect(search_object.radius_km).to be_nil
    end

    it 'uses radius_km when both radius and radius_km are present' do
      options = {
        query: 'bike',
        lat: 40.7128,
        long: -74.0060,
        radius: 10,
        radius_km: 25,
        min: 100,
        max: 500
      }

      search_object = cli.send(:search_object, options:)

      expect(search_object.radius_km).to eq(25)
    end
  end
end
