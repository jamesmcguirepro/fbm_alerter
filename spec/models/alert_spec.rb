# frozen_string_literal: true

require 'spec_helper'
require_relative '../../models/alert'

RSpec.describe Alert, type: :model do
  subject(:model) { Alert }

  describe '.create' do
    let(:now) { Time.now }
    let(:call) do
      model.create(
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
    let(:listing) { Listing.create(title: 'test', listing_id: '123') }

    before do
      Timecop.freeze(Time.local(2026))
    end

    after do
      Timecop.return
    end

    let(:call) { model.record_alert(listing_id: listing.id) }

    it 'records the alert' do
      expect { call }.to change { Alert.count }.by(1)
    end

    it 'uses the current timestamp' do
      expect(call.sent_at).to eq Time.now
    end
  end
end
