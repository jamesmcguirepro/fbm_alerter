# frozen_string_literal: true

class MarketplaceApp < Sinatra::Base
  helpers ViewHelpers

  get '/dashboard' do
    @search_count     = SavedSearch.count
    @active_count     = SavedSearch.where(active: true).count
    @listing_count    = Listing.count
    @alert_count      = Alert.count
    @api_call_count   = SearchRun.count
    @api_today_count  = SearchRun.where(created_at: Time.now.all_day).count
    @last_activity    = Listing.maximum(:last_seen_at)
    @recent_listings  = Listing.order(updated_at: :desc).limit(10)

    erb :dashboard
  end

  post '/dashboard/run-all' do
    @log = run_monitor_capture do |monitor|
      monitor.execute_saved_searches
    end

    @search_count     = SavedSearch.count
    @active_count     = SavedSearch.where(active: true).count
    @listing_count    = Listing.count
    @alert_count      = Alert.count
    @api_call_count   = SearchRun.count
    @api_today_count  = SearchRun.where(created_at: Time.now.all_day).count
    @last_activity    = Listing.maximum(:last_seen_at)

    erb :dashboard, layout: false
  end
end
