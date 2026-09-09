# frozen_string_literal: true

require 'spec_helper'
require_relative '../../models/listing'

RSpec.describe Listing do
  subject(:model) { Listing }

  # before do
  #   Listing.delete_all
  # end

  describe '.create' do
    let(:call) do
      model.create(
        title: 'test'
      )
    end
    it 'creates a listing' do
      expect(call.title).to eq 'test'
    end

    it 'generates an id' do
      expect(call.id).to be_a Integer
    end

    it 'only has one' do
      call
      expect(Listing.count).to eq 1
    end
  end
end
