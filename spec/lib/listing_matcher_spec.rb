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

    it 'matches reversed compound model suffixes like "300te"' do
      expect(matcher(query: 'te 300').title_match?(title: 'Husqvarna 300te')).to be(true)
    end

    it 'matches compound suffixes with the prefix first like "te300"' do
      expect(matcher(query: 'te 300').title_match?(title: 'Husqvarna te300')).to be(true)
    end

    it 'does not match short query keywords as substrings of unrelated words' do
      expect(matcher(query: 'husqvarna te 300').title_match?(title: '2016 GMC Terrain')).to be(false)
    end

    it 'does not match "te" inside "Tex"' do
      expect(matcher(query: 'te 300').title_match?(title: '2004 Big Tex 14gn')).to be(false)
    end

    it 'does not match "te" inside "Date"' do
      expect(matcher(query: 'husqvarna te 300').title_match?(title: 'Rolex Submariner Date Men Watch 41mm')).to be(false)
    end

    it 'does not match "300" inside "1500"' do
      expect(matcher(query: 'husqvarna te 300').title_match?(title: '2005 Chevrolet Silverado 1500')).to be(false)
    end

    it 'does not match "te" inside "mustang"' do
      expect(matcher(query: 'husqvarna te 300').title_match?(title: '2016 Ford Mustang EcoBoost Coupe 2D')).to be(false)
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

    it 'treats a digit with an inch mark in the title as the word inch' do
      expect(matcher(query: '16 inch tv').title_match?(title: 'Samsung 55" 4k TV')).to be(true)
    end

    it 'treats a digit with an inch mark in the query as the word inch' do
      expect(matcher(query: '55" tv').title_match?(title: 'Samsung 55 inch 4k TV')).to be(true)
    end

    it 'treats a digit with a foot mark in the title as the word foot' do
      expect(matcher(query: '6 foot shelf').title_match?(title: "6' wide shelf")).to be(true)
    end

    it 'treats a digit with a foot mark in the query as the word foot' do
      expect(matcher(query: "6' shelf").title_match?(title: '6 foot wide shelf')).to be(true)
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

      it 'maps ft to foot' do
        expect(matcher(query: 'ft cabinet').title_match?(title: '6 foot tall cabinet')).to be(true)
        expect(matcher(query: 'ft cabinet').title_match?(title: "6' tall cabinet")).to be(true)
      end
    end
  end

  describe '#exact_match?' do
    it 'requires every query keyword to be present in the title' do
      expect(matcher(query: 'husqvarna te 300').exact_match?(title: '2022 Husqvarna TE 300')).to be(true)
      expect(matcher(query: 'husqvarna te 300').exact_match?(title: '2022 Husqvarna TE 350')).to be(false)
    end

    it 'returns false for nil or empty titles and empty queries' do
      expect(matcher(query: 'husqvarna').exact_match?(title: nil)).to be(false)
      expect(matcher(query: 'husqvarna').exact_match?(title: '')).to be(false)
      expect(matcher(query: '').exact_match?(title: 'Husqvarna TE 300')).to be(false)
    end

    it 'counts a digit with an inch mark as the word inch' do
      m = matcher(query: 'macbook pro 16 inch m1')

      expect(m.exact_match?(title: 'Apple MacBook Pro - 16" M1 16Gb RAM')).to be(true)
      expect(m.exact_match?(title: 'Apple MacBook Pro 16 inch M1')).to be(true)
    end

    it 'counts a digit with a foot mark as the word foot' do
      m = matcher(query: '6 foot shelf')

      expect(m.exact_match?(title: '6" wide shelf')).to be(false)
      expect(m.exact_match?(title: "6' wide shelf")).to be(true)
      expect(m.exact_match?(title: '6 foot wide shelf')).to be(true)
    end

    it 'does not treat a quote mark not preceded by a digit as inch' do
      expect(matcher(query: 'macbook inch pro').exact_match?(title: '"MacBook" Pro 16')).to be(false)
    end
  end
end
