# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ReverseGeocoder do
  let(:url) { %r{nominatim\.openstreetmap\.org/reverse} }

  def stub_reverse(body)
    stub_request(:get, url).to_return(
      status: 200,
      body: body.to_json,
      headers: { 'Content-Type' => 'application/json' }
    )
  end

  it 'builds "City, State" from the address' do
    stub_reverse('address' => { 'city' => 'Austin', 'state' => 'Texas' })

    expect(described_class.lookup(lat: 30.2672, long: -97.7431)).to eq('Austin, Texas')
  end

  it 'falls back to county (without the "County" suffix) when there is no city' do
    stub_reverse('address' => { 'county' => 'Santa Barbara County', 'state' => 'California' })

    expect(described_class.lookup(lat: 34.4329, long: -119.7192)).to eq('Santa Barbara, California')
  end

  it 'falls back to display_name when there is no address detail' do
    stub_reverse('display_name' => 'Somewhere Special')

    expect(described_class.lookup(lat: 1.0, long: 2.0)).to eq('Somewhere Special')
  end

  it 'sends an identifying User-Agent' do
    stub_reverse('address' => { 'city' => 'Austin', 'state' => 'Texas' })
    described_class.lookup(lat: 30.2672, long: -97.7431)

    expect(a_request(:get, url).with(headers: { 'User-Agent' => /\Afbm_alerter\// })).to have_been_made.once
  end

  it 'returns nil on a non-200 response' do
    stub_request(:get, url).to_return(status: 500, body: 'boom')

    expect(described_class.lookup(lat: 1.0, long: 2.0)).to be_nil
  end

  it 'returns nil on a network error' do
    stub_request(:get, url).to_raise(SocketError)

    expect(described_class.lookup(lat: 1.0, long: 2.0)).to be_nil
  end

  it 'returns nil without coordinates' do
    expect(described_class.lookup(lat: nil, long: nil)).to be_nil
    expect(a_request(:get, url)).not_to have_been_made
  end
end
