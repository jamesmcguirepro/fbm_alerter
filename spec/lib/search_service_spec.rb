# frozen_string_literal: true

require 'spec_helper'
require_relative '../../lib/search_service'

RSpec.describe SearchService do
  subject(:service) { described_class.new(search_object:, client:) }

  let(:client) { double('client') }
  let(:search_object) do
    SearchObject.new(
      id: nil,
      query: 'husqvarna te 300',
      lat: 40.7128,
      long: -74.0060,
      min_price: nil,
      max_price: nil,
      radius_km: 65,
      condition: nil,
      delivery_method: nil
    )
  end

  def listing(id:, title:, creation_time: nil)
    { 'id' => id, 'title' => title, 'creation_time' => creation_time }
  end

  def page(listings:, cursor: nil, has_next_page: true)
    { listings:, cursor:, has_next_page: }
  end

  def stub_pages(*pages)
    allow(client).to receive(:search_page) do |search_object: nil, cursor: nil, &on_request|
      on_request&.call
      pages.shift || { listings: [], cursor: nil, has_next_page: false }
    end
  end

  it 'returns only listings whose title matches the query' do
    stub_pages(page(listings: [
                       listing(id: '1', title: '2022 Husqvarna TE 300'),
                       listing(id: '2', title: 'Toyota Camry'),
                       listing(id: '3', title: 'Husqvarna FE 350')
                     ], has_next_page: false))

    expect(service.run.map(&:listing_id)).to contain_exactly('1', '3')
  end

  it 'builds ListingObjects stamped with the search query' do
    stub_pages(page(listings: [listing(id: '1', title: 'Husqvarna TE 300')], has_next_page: false))

    result = service.run.first

    expect(result).to be_a(ListingObject)
    expect(result.search_query).to eq('husqvarna te 300')
  end

  it 'stops paging when a page has no title matches' do
    stub_pages(
      page(listings: [listing(id: '1', title: 'Toyota Camry'), listing(id: '2', title: 'Honda Civic')], cursor: 'page-2'),
      page(listings: [listing(id: '3', title: 'Husqvarna TE 300')], cursor: 'page-3')
    )

    result = service.run

    expect(result).to be_empty
    expect(client).to have_received(:search_page).once
  end

  it 'continues to the next page while matches are found' do
    stub_pages(
      page(listings: [listing(id: '1', title: 'Husqvarna TE 300')], cursor: 'page-2'),
      page(listings: [listing(id: '2', title: 'Husqvarna TC 250')], has_next_page: false)
    )

    result = service.run

    expect(client).to have_received(:search_page).twice
    expect(client).to have_received(:search_page).with(search_object:, cursor: 'page-2').at_least(:once)
    expect(result.map(&:listing_id)).to contain_exactly('1', '2')
  end

  it 'stops when the API reports no next page' do
    stub_pages(
      page(listings: [listing(id: '1', title: 'Husqvarna TE 300')], cursor: 'page-2', has_next_page: false),
      page(listings: [listing(id: '2', title: 'Husqvarna TC 250')], cursor: 'page-3')
    )

    service.run

    expect(client).to have_received(:search_page).once
  end

  it 'stops when the page has no cursor' do
    stub_pages(
      page(listings: [listing(id: '1', title: 'Husqvarna TE 300')], cursor: nil),
      page(listings: [listing(id: '2', title: 'Husqvarna TC 250')], cursor: 'page-3')
    )

    service.run

    expect(client).to have_received(:search_page).once
  end

  it 'caps paging at MAX_PAGES even when every page matches' do
    stub_pages(
      *Array.new(described_class::MAX_PAGES + 1) do |index|
        page(listings: [listing(id: index.to_s, title: 'Husqvarna TE 300')], cursor: "page-#{index + 2}")
      end
    )

    service.run

    expect(client).to have_received(:search_page).exactly(described_class::MAX_PAGES).times
  end

  it 'de-duplicates listings returned across pages' do
    stub_pages(
      page(listings: [listing(id: '1', title: 'Husqvarna TE 300')], cursor: 'page-2'),
      page(listings: [listing(id: '1', title: 'Husqvarna TE 300')], has_next_page: false)
    )

    expect(service.run.map(&:listing_id)).to eq(['1'])
  end

  it 'sorts matches newest first' do
    stub_pages(page(listings: [
                      listing(id: '1', title: 'Husqvarna TE 300', creation_time: '2026-10-01T10:00:00.000Z'),
                      listing(id: '2', title: 'Husqvarna TE 300', creation_time: '2026-10-18T10:00:00.000Z'),
                      listing(id: '3', title: 'Husqvarna TE 300', creation_time: '2026-10-10T10:00:00.000Z')
                    ], has_next_page: false))

    expect(service.run.map(&:listing_id)).to eq(%w[2 3 1])
  end

  it 'yields once per API request so callers can account for credits' do
    stub_pages(
      page(listings: [listing(id: '1', title: 'Husqvarna TE 300')], cursor: 'page-2'),
      page(listings: [listing(id: '2', title: 'Husqvarna TC 250')], has_next_page: false)
    )

    requests = 0
    service.run { requests += 1 }

    expect(requests).to eq(2)
  end

  it 'returns no listings when the API returns an empty page' do
    stub_pages(page(listings: [], has_next_page: false))

    expect(service.run).to eq([])
  end

  it 'tolerates a malformed page response' do
    stub_pages({})

    expect(service.run).to eq([])
  end
end
