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
end
