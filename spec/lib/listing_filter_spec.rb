# frozen_string_literal: true

require 'spec_helper'
require_relative '../../lib/listing_filter'

RSpec.describe ListingFilter do
  describe '#filter' do
    it 'raises NotImplementedError by default' do
      expect { described_class.new.filter(nil, nil) }.to raise_error(NotImplementedError)
    end
  end

  describe '#before_search' do
    it 'is a no-op by default' do
      filter = described_class.new
      expect { filter.before_search(nil) }.not_to raise_error
    end
  end

  describe '#after_search' do
    it 'is a no-op by default' do
      filter = described_class.new
      expect { filter.after_search({}) }.not_to raise_error
    end
  end
end
