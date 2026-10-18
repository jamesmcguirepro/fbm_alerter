# frozen_string_literal: true

require 'spec_helper'
require 'rack/test'
require_relative '../../app/marketplace_app'

RSpec.describe MarketplaceApp do
  include Rack::Test::Methods

  def app
    MarketplaceApp.new
  end

  # Rack::Test omits HTTP_HOST by default; Rack::Protection wants it.
  def get(uri, params = {}, env = {}, &block)
    super(uri, params, env.merge('HTTP_HOST' => 'localhost'), &block)
  end

  def post(uri, params = {}, env = {}, &block)
    super(uri, params, env.merge('HTTP_HOST' => 'localhost'), &block)
  end

  def patch(uri, params = {}, env = {}, &block)
    super(uri, params, env.merge('HTTP_HOST' => 'localhost'), &block)
  end

  def delete(uri, params = {}, env = {}, &block)
    super(uri, params, env.merge('HTTP_HOST' => 'localhost'), &block)
  end

  let(:api_url) { %r{https://api\.sociavault\.com/v1/scrape/facebook-marketplace/search} }

  before do
    # Never hit real SMTP from web specs.
    allow(Mailer).to receive(:send_email)

    stub_request(:get, api_url).to_return(
      status: 200,
      body: {
        'data' => {
          'listings' => {
            '1' => {
              'id' => 'abc123',
              'title' => 'Test Bike',
              'price' => { 'amount' => 250 },
              'location' => { 'display_name' => 'New York, NY' },
              'url' => 'https://facebook.com/marketplace/item/abc123/',
              'primary_photo' => { 'url' => 'https://example.com/photo.jpg' },
              'is_sold' => false
            }
          }
        }
      }.to_json,
      headers: { 'Content-Type' => 'application/json' }
    )

    # Reverse geocoding on the searches page must never hit the network.
    stub_request(:get, %r{nominatim\.openstreetmap\.org/reverse}).to_return(
      status: 200,
      body: {
        'address' => { 'city' => 'New York', 'state' => 'New York' }
      }.to_json,
      headers: { 'Content-Type' => 'application/json' }
    )

    # Credit balance shown on the dashboard (loaded by htmx).
    stub_request(:get, %r{https://api\.sociavault\.com/v1/credits}).to_return(
      status: 200,
      body: { 'credits' => 950, 'subscriptionStatus' => 'active', 'subscriptionId' => nil }.to_json,
      headers: { 'Content-Type' => 'application/json' }
    )
  end

  describe 'GET /health' do
    it 'returns ok' do
      get '/health'
      expect(last_response.status).to eq(200)
      expect(JSON.parse(last_response.body)).to include('status' => 'ok')
    end
  end

  describe 'GET /dashboard' do
    it 'renders' do
      get '/dashboard'
      expect(last_response.status).to eq(200)
      expect(last_response.body).to include('Dashboard')
    end

    it 'loads the credit balance asynchronously so the page never blocks' do
      get '/dashboard'

      expect(last_response.body).to include('id="credits-card"')
      expect(last_response.body).to include('hx-get="/dashboard/credits"')
      expect(last_response.body).to include('hx-trigger="load, refresh"')
    end

    it 'links the credit card to the SociaVault dashboard' do
      get '/dashboard'

      expect(last_response.body).to include('href="https://sociavault.com/dashboard"')
      expect(last_response.body).to include('target="_blank"')
    end

    it 'links each recent listing row to the listing' do
      Listing.create!(
        listing_id: 'recent-1', title: 'Recent Bike',
        url: 'https://facebook.com/marketplace/item/recent-1/'
      )

      get '/dashboard'

      expect(last_response.body)
        .to include('data-href="https://facebook.com/marketplace/item/recent-1/"')
      expect(last_response.body).to include('>Recent Bike</a>')
    end

    it 'leaves a recent listing unlinked when it has no URL' do
      Listing.create!(listing_id: 'recent-2', title: 'Mystery Item')

      get '/dashboard'

      expect(last_response.body).to include('Mystery Item')
      expect(last_response.body).not_to include('data-href=')
    end

    # The shared rows partial would happily render the thumbnail column here;
    # the dashboard passes thumbnail: false, and this is what that buys.
    it 'leaves the thumbnail column off the recent listings table' do
      Listing.create!(
        listing_id: 'recent-thumb', title: 'Photo Bike', image_url: 'https://example.com/p.jpg'
      )

      get '/dashboard'

      expect(last_response.body).to include('Photo Bike')
      expect(last_response.body).not_to include('<img src=')
    end

    it 'links a recent listing back to the search that produced it' do
      search = SavedSearch.create!(
        query: 'bike', lat: 40.7128, long: -74.0060, email: 'owner@example.com'
      )
      Listing.create!(
        listing_id: 'recent-3', title: 'Search Bike', search_query: 'bike',
        url: 'https://facebook.com/marketplace/item/recent-3/'
      )

      get '/dashboard'

      expect(last_response.body).to include(%(href="/searches?inactive=1#search-row-#{search.id}"))
    end

    it 'does not count a discarded search' do
      SavedSearch.create!(
        query: 'still here', lat: 40.7128, long: -74.0060, email: 'owner@example.com', active: true
      )
      gone = SavedSearch.create!(
        query: 'gone', lat: 40.7128, long: -74.0060, email: 'owner@example.com', active: true
      )
      gone.discard

      get '/dashboard'

      expect(last_response.body).to match(%r{<h2>Saved searches</h2>\s*<div class="value">1</div>})
      expect(last_response.body).to include('1 active')
    end

    it 're-renders the dashboard with the run log after running every search' do
      SavedSearch.create!(
        query: 'bike', lat: 40.7128, long: -74.0060, email: 'owner@example.com', active: true
      )

      post '/dashboard/run-all'

      expect(last_response.status).to eq(200)
      expect(last_response.body).to include('id="run-all-log"')
      expect(last_response.body).to include('Searching: bike')
      expect(last_response.body).to include('Recent listings')
    end
  end

  describe 'GET /searches' do
    let!(:search) do
      SavedSearch.create!(
        query: 'bike', lat: 40.7128, long: -74.0060,
        min_price: 100, max_price: 500, email: 'owner@example.com',
        active: true
      )
    end

    it 'renders the index' do
      get '/searches'
      expect(last_response.status).to eq(200)
    end

    it 'renders the active badge as HTML, not escaped text' do
      get '/searches'
      expect(last_response.body).to include('<span class="badge badge--active">Active</span>')
      expect(last_response.body).not_to include('&lt;span')
    end

    it 'wires the row to the toggle and delete htmx endpoints' do
      get '/searches'
      expect(last_response.body).to include(%(hx-post="/searches/#{search.id}/toggle"))
      expect(last_response.body).to include(%(hx-delete="/searches/#{search.id}"))
      expect(last_response.body).to include(%(id="search-row-#{search.id}"))
    end

    it 'renders the two column headers (Run now and Actions)' do
      get '/searches'

      expect(last_response.body).to include('<th>Run now</th>')
      expect(last_response.body).to include('<th>Actions</th>')
    end

    it 'renders the run column with a modal dialog' do
      get '/searches'

      expect(last_response.body).to include(%(class="run-col"))
      expect(last_response.body).to include(%(dialog id="run-modal-#{search.id}" class="run-modal"))
      expect(last_response.body).to include(%(id="run-modal-body-#{search.id}"))
      # The dialog must start closed: no `open` attribute, otherwise the modal
      # shows on every page load.
      expect(last_response.body).not_to match(/<dialog[^>]*\bopen\b/)
    end

    it 'renders the actions column with padded buttons' do
      get '/searches'

      expect(last_response.body).to include(%(class="actions-col"))
      expect(last_response.body).to include(%(hx-post="/searches/#{search.id}/toggle"))
      expect(last_response.body).to include(%(hx-delete="/searches/#{search.id}"))
      expect(last_response.body).to include(%(href="/searches/#{search.id}/edit"))
    end

    it 'opens the run modal when Run now is clicked' do
      get '/searches'

      expect(last_response.body).to include(%(hx-on::before-request="this.disabled=true; this.textContent='Running…'; document.getElementById('run-modal-#{search.id}').showModal()"))
      expect(last_response.body).to include(%(hx-on::after-request="this.disabled=false; this.textContent='Run now'"))
      # The modal must stay open so the run log is visible — it should not be
      # auto-closed when the request settles.
      expect(last_response.body).not_to include(%(after-settle))
      expect(last_response.body).not_to include("run-modal-#{search.id}').close()")
    end

    it 'hides a discarded search' do
      search.discard

      get '/searches?inactive=1'

      expect(last_response.body).not_to include("search-row-#{search.id}")
      expect(last_response.body).not_to include('>bike<')
    end

    it 'escapes the query it echoes back into the row' do
      SavedSearch.create!(
        query: 'a "quoted" <b>term</b>', lat: 40.7128, long: -74.0060, email: 'owner@example.com'
      )

      get '/searches'

      expect(last_response.body).to include('a &quot;quoted&quot; &lt;b&gt;term&lt;/b&gt;')
      expect(last_response.body).not_to include('<b>term</b>')
    end

    it 'shows the resolved place name together with the raw coordinates' do
      get '/searches'
      expect(last_response.body).to include('New York')
      expect(last_response.body).to include('40.7128, -74.0060')
      expect(search.reload.resolved_location).to eq('New York')
    end

    it 'shows how many API calls each search has made' do
      SearchRun.create!(saved_search_id: search.id, success: true)
      SearchRun.create!(saved_search_id: search.id, success: true)

      get '/searches'

      expect(last_response.body).to include(%(<div id="search-calls-#{search.id}">))
      expect(last_response.body).to include('<div class="calls-count">2</div>')
    end

    it 'hides inactive searches unless explicitly requested' do
      paused = SavedSearch.create!(
        query: 'paused', lat: 40.7128, long: -74.0060,
        email: 'owner@example.com', active: false
      )

      get '/searches'
      expect(last_response.body).not_to include(%(id="search-row-#{paused.id}"))

      get '/searches?inactive=1'
      expect(last_response.body).to include(%(id="search-row-#{paused.id}"))
      expect(last_response.body).to include(%(id="search-row-#{search.id}"))
    end
  end

  describe 'POST /searches' do
    it 'creates a saved search and redirects' do
      expect do
        post '/searches', {
          query: 'bike', lat: 40.7128, long: -74.0060,
          min_price: 100, max_price: 500, radius_km: 65, email: 'owner@example.com'
        }
      end.to change(SavedSearch, :count).by(1)

      expect(last_response.status).to eq(302)
      expect(last_response.headers['Location']).to end_with('/searches')
    end

    it 'rejects out-of-range coordinates and shows an error' do
      expect do
        post '/searches', {
          query: 'bike', lat: 40.7128, long: -11971922006451092,
          radius_km: 65, email: 'owner@example.com'
        }
      end.not_to change(SavedSearch, :count)

      expect(last_response.status).to eq(422)
      expect(last_response.body).to include('must be a number between -180 and 180')
    end

    it 'rejects an out-of-range radius and shows an error' do
      expect do
        post '/searches', {
          query: 'bike', lat: 40.7128, long: -74.0060,
          radius_km: 2000, email: 'owner@example.com'
        }
      end.not_to change(SavedSearch, :count)

      expect(last_response.status).to eq(422)
      expect(last_response.body).to include('must be a number between 5 and 1000 km')
    end

    it 'escapes the values it re-renders in the form' do
      post '/searches', {
        query: '<script>alert(1)</script>', lat: 40.7128, long: -74.0060,
        radius_km: 2000, email: 'owner@example.com'
      }

      expect(last_response.status).to eq(422)
      expect(last_response.body).to include('&lt;script&gt;alert(1)&lt;/script&gt;')
      expect(last_response.body).not_to include('<script>alert(1)</script>')
    end
  end

  describe 'GET /searches/:id/edit' do
    it 'renders the edit form' do
      search = SavedSearch.create!(
        query: 'bike', lat: 40.7128, long: -74.0060,
        min_price: 100, max_price: 500, email: 'owner@example.com'
      )
      get "/searches/#{search.id}/edit"
      expect(last_response.status).to eq(200)
    end
  end

  describe 'PATCH /searches/:id' do
    it 'forks a new search and pauses the original' do
      original = SavedSearch.create!(
        query: 'bike', lat: 40.7128, long: -74.0060,
        min_price: 100, max_price: 500, email: 'owner@example.com', active: true
      )

      expect do
        patch "/searches/#{original.id}", {
          name: 'My Bike Search', query: 'bike', lat: 40.7128, long: -74.0060,
          min_price: 100, max_price: 500, radius_km: 65, email: 'owner@example.com',
          active: 'on'
        }
      end.to change(SavedSearch, :count).by(1)

      expect(last_response.status).to eq(302)

      replacement = SavedSearch.where.not(id: original.id).last
      expect(replacement.name).to eq('My Bike Search')
      expect(replacement.active).to be true
      expect(original.reload.active).to be false
    end

    it 'rejects out-of-range coordinates and keeps the stored value' do
      search = SavedSearch.create!(
        query: 'bike', lat: 40.7128, long: -74.0060,
        min_price: 100, max_price: 500, email: 'owner@example.com'
      )
      patch "/searches/#{search.id}", {
        query: 'bike', lat: 40.7128, long: -11971922006451092,
        radius_km: 65, email: 'owner@example.com'
      }
      expect(last_response.status).to eq(422)
      expect(search.reload.long.to_f).to be_within(0.0001).of(-74.006)
      expect(last_response.body).to include('must be a number between -180 and 180')
    end
  end

  describe 'DELETE /searches/:id' do
    let!(:search) do
      SavedSearch.create!(
        query: 'bike', lat: 40.7128, long: -74.0060,
        min_price: 100, max_price: 500, email: 'owner@example.com'
      )
    end

    it 'soft deletes the saved search' do
      delete "/searches/#{search.id}"

      expect(search.reload).to be_discarded
      expect(SavedSearch.exists?(search.id)).to be true
    end

    it 'returns an empty 200 so htmx removes the row (not a redirect)' do
      delete "/searches/#{search.id}"
      expect(last_response.status).to eq(200)
      expect(last_response.body.strip).to eq('')
    end

    it 'soft deletes a search that has alerts and runs, keeping the history' do
      listing = Listing.create!(listing_id: 'history-1', title: 'History Bike')
      Alert.create!(listing_id: listing.id, search_id: search.id, sent_at: Time.now)
      SearchRun.create!(saved_search_id: search.id, success: true)

      delete "/searches/#{search.id}"

      expect(last_response.status).to eq(200)
      expect(search.reload).to be_discarded
      expect(Alert.count).to eq(1)
      expect(SearchRun.count).to eq(1)
    end
  end

  describe 'POST /searches/:id/toggle' do
    let!(:search) do
      SavedSearch.create!(
        query: 'bike', lat: 40.7128, long: -74.0060,
        min_price: 100, max_price: 500, email: 'owner@example.com',
        active: true
      )
    end

    it 'flips the active flag' do
      post "/searches/#{search.id}/toggle"
      expect(search.reload.active).to be false
    end

    it 'returns the re-rendered row fragment, not a redirect' do
      post "/searches/#{search.id}/toggle"
      expect(last_response.status).to eq(200)
      expect(last_response.body).to include("<tr id=\"search-row-#{search.id}\"")
      expect(last_response.body).to include('Resume')
    end
  end

  describe 'POST /searches/:id/run' do
    it 'runs a single search and returns the log' do
      search = SavedSearch.create!(
        query: 'bike', lat: 40.7128, long: -74.0060,
        min_price: 100, max_price: 500, email: 'owner@example.com'
      )
      post "/searches/#{search.id}/run"
      expect(last_response.status).to eq(200)
      expect(last_response.body).to include('Searching')
    end

    it 'swaps in the updated call count out of band' do
      search = SavedSearch.create!(
        query: 'bike', lat: 40.7128, long: -74.0060,
        min_price: 100, max_price: 500, email: 'owner@example.com'
      )

      post "/searches/#{search.id}/run"

      expect(last_response.body).to include(%(<div id="search-calls-#{search.id}" hx-swap-oob="true">))
      # A bare <td> is invalid at the top level of the fragment htmx parses, so
      # the browser drops it and its children leak into the swap target.
      expect(last_response.body).not_to include('<td')
      expect(search.search_runs.count).to eq(1)
    end
  end

  describe 'GET /listings' do
    it 'renders' do
      get '/listings'
      expect(last_response.status).to eq(200)
    end

    it 'links a listing back to the search that produced it' do
      search = SavedSearch.create!(
        query: 'bike', lat: 40.7128, long: -74.0060,
        min_price: 100, max_price: 500, email: 'owner@example.com'
      )
      Listing.create!(
        listing_id: 'abc123', title: 'Test Bike', search_query: 'bike',
        url: 'https://facebook.com/marketplace/item/abc123/'
      )

      get '/listings'
      expect(last_response.status).to eq(200)
      expect(last_response.body).to include(%(href="/searches?inactive=1#search-row-#{search.id}"))
      expect(last_response.body).to include(%(data-href="https://facebook.com/marketplace/item/abc123/"))
      expect(last_response.body).to include(
        %(<a href="https://facebook.com/marketplace/item/abc123/" target="_blank" rel="noopener">Test Bike</a>)
      )
    end

    it 'does not link a listing that has no URL' do
      Listing.create!(listing_id: 'no-url', title: 'Mystery Item')

      get '/listings'
      expect(last_response.body).to include('Mystery Item')
      expect(last_response.body).not_to include('data-href=')
    end

    it 'filters by title, case-insensitively' do
      Listing.create!(listing_id: 'filter-1', title: 'Blue Bike')
      Listing.create!(listing_id: 'filter-2', title: 'Red Truck')

      get '/listings', { 'query' => 'bike' }

      expect(last_response.status).to eq(200)
      expect(last_response.body).to include('Blue Bike')
      expect(last_response.body).not_to include('Red Truck')
    end

    it 'escapes the sold filter when building pagination links' do
      26.times { |i| Listing.create!(listing_id: "page-#{i}", title: "Item #{i}") }

      get '/listings', { 'sold' => '1"><script>alert(1)</script>' }

      expect(last_response.body).not_to include('<script>alert(1)</script>')
      expect(last_response.body).to include('sold=1%22%3E')
    end

    it 'escapes the title filter it echoes back into the form' do
      get '/listings', { 'query' => '"><script>alert(1)</script>' }

      expect(last_response.status).to eq(200)
      expect(last_response.body).not_to include('<script>alert(1)</script>')
      expect(last_response.body).to include('value="&quot;&gt;&lt;script&gt;alert(1)&lt;/script&gt;"')
    end

    it 'still filters by the title after escaping it' do
      Listing.create!(listing_id: 'quote-1', title: 'A "quoted" bike')

      get '/listings', { 'query' => '"quoted"' }

      expect(last_response.body).to include('A &quot;quoted&quot; bike')
    end

    # The dashboard and this page share app/views/listings/_rows.erb, so these
    # two specs pin the flags that make the two tables different.
    it 'shows the thumbnail column and which run found the listing' do
      search = SavedSearch.create!(
        query: 'bike', lat: 40.7128, long: -74.0060, email: 'owner@example.com'
      )
      run = SearchRun.create!(saved_search_id: search.id, success: true)
      Listing.create!(
        listing_id: 'thumb-1', title: 'Photo Bike', image_url: 'https://example.com/p.jpg',
        url: 'https://facebook.com/marketplace/item/thumb-1/', search_run_id: run.id
      )

      get '/listings'

      expect(last_response.body).to include('<img src="https://example.com/p.jpg"')
      expect(last_response.body).to include('found ')
    end

    it 'shows the run that discovered the listing' do
      search = SavedSearch.create!(
        query: 'bike', lat: 40.7128, long: -74.0060, email: 'owner@example.com'
      )
      run = SearchRun.create!(saved_search_id: search.id, success: true)
      Listing.create!(
        listing_id: 'run-1', title: 'Run Bike', search_query: 'bike', search_run_id: run.id
      )

      get '/listings'

      expect(last_response.body).to match(/found [A-Z][a-z]{2} \d{2}, \d{4}/)
    end
  end

  describe 'GET /alerts' do
    it 'renders' do
      get '/alerts'
      expect(last_response.status).to eq(200)
    end

    it 'links each alert back to the search that produced it' do
      search = SavedSearch.create!(
        query: 'bike', lat: 40.7128, long: -74.0060, email: 'owner@example.com'
      )
      listing = Listing.create!(listing_id: 'alert-1', title: 'Alert Bike', search_query: 'bike')
      Alert.record_alert(listing_id: listing.id, search_id: search.id)

      get '/alerts'

      expect(last_response.body).to include(%(href="/searches?inactive=1#search-row-#{search.id}"))
      expect(last_response.body).to include('Alert Bike')
    end

    it 'shows the send time to the second' do
      search = SavedSearch.create!(
        query: 'bike', lat: 40.7128, long: -74.0060, email: 'owner@example.com'
      )
      listing = Listing.create!(listing_id: 'alert-seconds', title: 'Timed Bike')
      Alert.create!(
        listing_id: listing.id, search_id: search.id, sent_at: Time.utc(2026, 6, 1, 3, 4, 5)
      )

      get '/alerts'

      # 03:04:05 UTC on Jun 1 is 08:04:05 PM on May 31 in Pacific (PDT).
      expect(last_response.body).to include('May 31, 2026 08:04:05 PM PDT')
    end

    it 'leaves seconds off the other screens' do
      Listing.create!(
        listing_id: 'no-seconds', title: 'Plain Bike', last_seen_at: Time.utc(2026, 6, 1, 3, 4, 5)
      )

      get '/listings'

      expect(last_response.body).to include('May 31, 2026 08:04 PM PDT')
      expect(last_response.body).not_to match(/\d{2}:\d{2}:\d{2}/)
    end

    it 'escapes listing titles' do
      search = SavedSearch.create!(
        query: 'bike', lat: 40.7128, long: -74.0060, email: 'owner@example.com'
      )
      listing = Listing.create!(listing_id: 'escaped-1', title: '<b>bold</b> bike')
      Alert.create!(listing_id: listing.id, search_id: search.id, sent_at: Time.now)

      get '/alerts'

      expect(last_response.body).to include('&lt;b&gt;bold&lt;/b&gt; bike')
      expect(last_response.body).not_to include('<b>bold</b>')
    end

    it 'keeps alerts from a discarded search, without a dead link' do
      search = SavedSearch.create!(
        query: 'bike', lat: 40.7128, long: -74.0060, email: 'owner@example.com'
      )
      listing = Listing.create!(listing_id: 'escaped-2', title: 'Orphan Bike')
      Alert.create!(listing_id: listing.id, search_id: search.id, sent_at: Time.now)
      search.discard

      get '/alerts'

      expect(last_response.body).to include('Orphan Bike')
      expect(last_response.body).not_to include("#search-row-#{search.id}")
    end
  end

  describe 'GET /settings' do
    it 'renders' do
      get '/settings'
      expect(last_response.status).to eq(200)
    end

    it 'shows only the first 7 and last 3 characters of the API key' do
      get '/settings'
      expect(last_response.body).to include('sk_test*key')
      expect(last_response.body).not_to include('sk_test_key')
    end

    it 'prefills the test-email field with EMAIL_FROM, labelled and clearable' do
      get '/settings'
      expect(last_response.body).to include('<label for="test-email-to">To</label>')
      expect(last_response.body).to include('id="test-email-to"')
      expect(last_response.body).to include('value="test@example.com"')
      expect(last_response.body).to include('data-clear="#test-email-to"')
    end

    it 'no longer shows an EMAIL_TO setting' do
      get '/settings'
      expect(last_response.body).not_to include('EMAIL_TO')
    end
  end

  describe 'POST /settings/test-email' do
    it 'sends the test email to the submitted address' do
      expect(Mailer).to receive(:send_email)
        .with(hash_including(to: 'dest@example.com'))

      post '/settings/test-email', { email: 'dest@example.com' }
      expect(last_response.status).to eq(302)
    end

    it 'does not send when the address is blank' do
      expect(Mailer).not_to receive(:send_email)

      post '/settings/test-email', { email: '' }
      expect(last_response.status).to eq(302)
    end

    it 'sends an email in the alert format' do
      expect(Mailer).to receive(:send_email) do |args|
        expect(args[:subject]).to include('road bike')
        expect(args[:html_body]).to include('<h1>road bike</h1>')
      end

      post '/settings/test-email', { email: 'dest@example.com' }
      expect(last_response.status).to eq(302)
    end
  end

  describe 'GET /dashboard' do
    it 'shows the running API-call (credit) total' do
      search = SavedSearch.create!(
        query: 'bike', lat: 40.7128, long: -74.0060, email: 'owner@example.com'
      )
      SearchRun.create!(saved_search_id: search.id, success: true)

      get '/dashboard'

      expect(last_response.status).to eq(200)
      expect(last_response.body).to include('API calls')
      expect(last_response.body).to include('1 credit each')
    end
  end

  describe 'GET /dashboard/credits' do
    it 'shows the remaining balance from SociaVault' do
      get '/dashboard/credits'

      expect(last_response.status).to eq(200)
      expect(last_response.body).to include('950')
      expect(last_response.body).to include('plan active')
    end

    it 'links to the SociaVault dashboard and keeps its refresh trigger' do
      get '/dashboard/credits'

      expect(last_response.body).to include('href="https://sociavault.com/dashboard"')
      # The partial deliberately has no `load` trigger: it is swapped in by a
      # `load` request, so re-adding it would re-fetch itself forever.
      expect(last_response.body).not_to include('hx-trigger="load')
      expect(last_response.body).to include('hx-trigger="refresh"')
    end

    it 'degrades gracefully when SociaVault is unreachable' do
      stub_request(:get, %r{https://api\.sociavault\.com/v1/credits}).to_raise(SocketError)

      get '/dashboard/credits'

      expect(last_response.status).to eq(200)
      expect(last_response.body).to include("can't reach SociaVault")
    end
  end

  describe 'time zone display' do
    it 'offers a dropdown in the header that defaults to Pacific' do
      get '/dashboard'

      expect(last_response.body).to include('name="tz"')
      expect(last_response.body)
        .to include('<option value="America/Los_Angeles" selected>Pacific (PT)</option>')
    end

    it 'is available on every page, not just the dashboard' do
      get '/listings'

      expect(last_response.body).to include('id="tz"')
      expect(last_response.body).to include('name="tz"')
    end

    it 'remembers the chosen zone' do
      post '/dashboard/timezone', { tz: 'America/New_York' }
      expect(last_response.status).to eq(302)

      get '/dashboard'
      expect(last_response.body)
        .to include('<option value="America/New_York" selected>Eastern (ET)</option>')
    end

    it 'returns you to the page you were on' do
      post '/dashboard/timezone', { tz: 'UTC', return_to: '/listings?query=bike' }

      expect(last_response.status).to eq(302)
      expect(last_response.headers['Location']).to end_with('/listings?query=bike')
    end

    it 'refuses to bounce to another site' do
      post '/dashboard/timezone', { tz: 'UTC', return_to: 'https://evil.example.com/' }

      expect(last_response.headers['Location']).to end_with('/dashboard')
    end

    it 'ignores an unknown zone' do
      post '/dashboard/timezone', { tz: 'Mars/Phobos' }

      get '/dashboard'
      expect(last_response.body)
        .to include('<option value="America/Los_Angeles" selected>Pacific (PT)</option>')
    end

    it 'renders timestamps in the chosen zone' do
      Listing.create!(
        listing_id: 'tz-1', title: 'TZ Bike', last_seen_at: Time.utc(2026, 6, 1, 3, 0, 0)
      )
      post '/dashboard/timezone', { tz: 'America/New_York' }

      get '/dashboard'

      # 03:00 UTC on Jun 1 is 11:00 PM on May 31 in Eastern daylight time.
      expect(last_response.body).to include('May 31, 2026 11:00 PM EDT')
    end
  end

  describe 'dry run' do
    it 'flags it in the header so a credit-free run is obvious' do
      allow(Config).to receive(:dry_run?).and_return(true)

      get '/dashboard'

      expect(last_response.body).to include('badge--dry-run')
    end

    it 'shows no badge when it is off' do
      get '/dashboard'

      expect(last_response.body).not_to include('badge--dry-run')
    end
  end

  describe 'GET /settings/email-preview' do
    it 'renders the alert email from stored listings without calling the API' do
      Listing.create!(
        listing_id: 'preview-1', title: 'Preview Bike', price: 1200,
        location: 'Austin, TX', search_query: 'bike',
        url: 'https://facebook.com/marketplace/item/preview-1/'
      )

      get '/settings/email-preview'

      expect(last_response.status).to eq(200)
      expect(last_response.content_type).to include('text/html')
      expect(last_response.body).to include('Preview Bike')
      expect(last_response.body).to include('<h1>bike</h1>')
    end

    it 'falls back to sample listings when the database is empty' do
      get '/settings/email-preview'

      expect(last_response.status).to eq(200)
      expect(last_response.body).to include('Vintage Road Bike')
    end
  end

  describe 'error handling' do
    before { allow(SavedSearch).to receive(:kept).and_raise('boom') }

    it 'renders a readable page rather than a JSON blob' do
      get '/searches'

      expect(last_response.status).to eq(500)
      expect(last_response.body).to include('Something went wrong')
      expect(last_response.body).to include('boom')
    end

    it 'escapes the error message' do
      allow(SavedSearch).to receive(:kept).and_raise('<script>alert(1)</script>')

      get '/searches'

      expect(last_response.body).not_to include('<script>alert(1)</script>')
      expect(last_response.body).to include('&lt;script&gt;')
    end

    it 'still returns JSON to clients that ask for it' do
      get '/searches', {}, { 'HTTP_ACCEPT' => 'application/json' }

      expect(last_response.status).to eq(500)
      expect(last_response.headers['Content-Type']).to include('application/json')
      expect(JSON.parse(last_response.body)).to include('status' => 'error', 'message' => 'boom')
    end
  end
end
