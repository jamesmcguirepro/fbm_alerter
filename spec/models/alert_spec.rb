# == Schema Information
#
# Table name: alerts
#
#  id         :integer          not null, primary key
#  listing_id :integer
#  sent_at    :datetime
#
require 'spec_helper'
require_relative '../../models/alert'

RSpec.describe Alert do
  subject(:model) { Alert }

  before do
    Alert.delete_all
  end

  describe '.create' do
    let(:now) { Time.now}
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
      expect(Listing.count).to eq 1
    end
  end

  describe '.record_alert' do
    let(:listing) { Listing.create(title: 'test') }

    before do
      freeze_time
    end

    after { Listing.last.destroy }

    let(:call) { model.record_alert(listing_id: listing.id) }

    it 'records the alert' do
      expect(call).to change { Alert.count }.by(1)
    end

    it 'uses the current timestamp' do
      expect(call.sent_at).to eq Time.now
    end
  end
end
