# frozen_string_literal: true

require 'spec_helper'
require_relative '../../lib/listing_matcher'

RSpec.describe ListingMatcher do
  def matcher(query:)
    described_class.new(query:)
  end

  describe '#title_match?' do
    it 'matches when the title contains any one query keyword' do
      expect(matcher(query: 'husqvarna te 300').title_match?(title: '2022 Husqvarna TE')).to be(true)
      expect(matcher(query: 'husqvarna te 300').title_match?(title: 'TE 300')).to be(true)
      expect(matcher(query: 'husqvarna te 300').title_match?(title: '300')).to be(true)
    end

    it 'does not require every keyword to be present' do
      expect(matcher(query: 'husqvarna te 300').title_match?(title: 'Husqvarna FE 350')).to be(true)
    end

    it 'matches case-insensitively' do
      expect(matcher(query: 'Husqvarna TE 300').title_match?(title: 'husqvarna te 300')).to be(true)
    end

    it 'matches keywords embedded in model names' do
      expect(matcher(query: 'te 300').title_match?(title: 'Husqvarna TE300i')).to be(true)
    end

    it 'returns false when no keyword is present' do
      expect(matcher(query: 'husqvarna te 300').title_match?(title: 'Kawasaki KX 250')).to be(false)
    end

    it 'returns false for nil or empty titles' do
      expect(matcher(query: 'husqvarna te 300').title_match?(title: nil)).to be(false)
      expect(matcher(query: 'husqvarna te 300').title_match?(title: '')).to be(false)
    end

    it 'returns false for an empty query' do
      expect(matcher(query: '').title_match?(title: 'Husqvarna TE 300')).to be(false)
    end

    context 'with nicknames' do
      it 'matches a nickname in the query against the full make in the title' do
        expect(matcher(query: 'husky te 300').title_match?(title: '2022 Husqvarna TE 300')).to be(true)
      end

      it 'matches a nickname in the title against the full make in the query' do
        expect(matcher(query: 'husqvarna te 300').title_match?(title: 'Husky TE 300')).to be(true)
      end

      it 'maps chevy to chevrolet' do
        expect(matcher(query: 'chevy silverado').title_match?(title: '2015 Chevrolet Silverado')).to be(true)
        expect(matcher(query: 'chevrolet silverado').title_match?(title: "2015 Chevy's Silverado")).to be(true)
      end

      it 'maps vw to volkswagen' do
        expect(matcher(query: 'vw golf').title_match?(title: '2012 Volkswagen Golf')).to be(true)
      end

      it 'maps merc to mercedes' do
        expect(matcher(query: 'merc 300').title_match?(title: 'Mercedes-Benz 300 SD')).to be(true)
      end
    end
  end
end
