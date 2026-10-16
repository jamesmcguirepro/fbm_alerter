# frozen_string_literal: true

require 'spec_helper'
require_relative '../../models/alert'

RSpec.describe Alert, type: :model do
  subject(:model) { Alert }

  let!(:listing) do
    Listing.create!(title: 'test', listing_id: 'listing-123', search_query: 'test')
  end

  let!(:saved_search) do
    SavedSearch.create!(query: 'test', email: 'owner@example.com')
  end

  describe '.create' do
    let(:now) { Time.now }
    let(:call) do
      model.create(
        listing_id: listing.id,
        search_id: saved_search.id,
        sent_at: now
      )
    end
    it 'creates an alert record' do
      expect(call.sent_at).to eq now
    end

    it 'generates an id' do
      expect(call.id).to be_a Integer
    end

    it 'only has one' do
      call
      expect(Alert.count).to eq 1
    end
  end

  describe '.record_alert' do
    before do
      Timecop.freeze(Time.local(2026))
    end

    after do
      Timecop.return
    end

    let(:call) { model.record_alert(listing_id: listing.id, search_id: saved_search.id) }

    it 'records the alert' do
      expect { call }.to change { Alert.count }.by(1)
    end

    it 'uses the current timestamp' do
      expect(call.sent_at).to eq Time.now
    end
  end
end
