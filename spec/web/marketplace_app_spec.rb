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
  end

  describe 'POST /searches' do
    it 'creates a saved search and redirects' do
      expect do
        post '/searches', {
          query: 'bike', lat: 40.7128, long: -74.0060,
          min_price: 100, max_price: 500, email: 'owner@example.com'
        }
      end.to change(SavedSearch, :count).by(1)

      expect(last_response.status).to eq(302)
      expect(last_response.headers['Location']).to end_with('/searches')
    end

    it 'rejects out-of-range coordinates and shows an error' do
      expect do
        post '/searches', {
          query: 'bike', lat: 40.7128, long: -11971922006451092,
          email: 'owner@example.com'
        }
      end.not_to change(SavedSearch, :count)

      expect(last_response.status).to eq(422)
      expect(last_response.body).to include('must be a number between -180 and 180')
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
    it 'updates the saved search' do
      search = SavedSearch.create!(
        query: 'bike', lat: 40.7128, long: -74.0060,
        min_price: 100, max_price: 500, email: 'owner@example.com'
      )
      patch "/searches/#{search.id}", {
        name: 'My Bike Search', query: 'bike', lat: 40.7128, long: -74.0060,
        min_price: 100, max_price: 500, email: 'owner@example.com'
      }
      expect(last_response.status).to eq(302)
      expect(search.reload.name).to eq('My Bike Search')
    end

    it 'rejects out-of-range coordinates and keeps the stored value' do
      search = SavedSearch.create!(
        query: 'bike', lat: 40.7128, long: -74.0060,
        min_price: 100, max_price: 500, email: 'owner@example.com'
      )
      patch "/searches/#{search.id}", {
        query: 'bike', lat: 40.7128, long: -11971922006451092, email: 'owner@example.com'
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

    it 'deletes the saved search' do
      delete "/searches/#{search.id}"
      expect(SavedSearch.exists?(search.id)).to be false
    end

    it 'returns an empty 200 so htmx removes the row (not a redirect)' do
      delete "/searches/#{search.id}"
      expect(last_response.status).to eq(200)
      expect(last_response.body.strip).to eq('')
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
  end

  describe 'GET /listings' do
    it 'renders' do
      get '/listings'
      expect(last_response.status).to eq(200)
    end
  end

  describe 'GET /alerts' do
    it 'renders' do
      get '/alerts'
      expect(last_response.status).to eq(200)
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
  end
end
