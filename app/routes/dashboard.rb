# frozen_string_literal: true

class MarketplaceApp < Sinatra::Base
  helpers ViewHelpers

  get '/dashboard' do
    load_dashboard

    erb :dashboard
  end

  post '/dashboard/run-all' do
    @log = run_monitor_capture do |monitor|
      monitor.execute_saved_searches
    end

    load_dashboard

    erb :dashboard, layout: false
  end

  # Remember the time-zone choice; it applies to every page.
  post '/dashboard/timezone' do
    zone = params[:tz].to_s
    session[:time_zone] = zone if ViewHelpers::TIME_ZONES.any? { |value, _| value == zone }
    redirect back_to(params[:return_to])
  end

  # Loaded by htmx so a slow (or down) SociaVault never blocks the dashboard.
  get '/dashboard/credits' do
    begin
      balance = SociaVaultClient.credits
      @credits = balance['credits']
      @credits_status = balance['subscriptionStatus']
      @credits_error = nil
    rescue StandardError => e
      @credits = nil
      @credits_status = nil
      @credits_error = e.message
    end

    erb :'dashboard/_credits', layout: false
  end

  private

  # Everything the dashboard view needs. Shared by the initial page load and
  # the htmx re-render after "Run all searches now", so the two can't drift.
  def load_dashboard
    @search_count       = SavedSearch.count
    @active_count       = SavedSearch.where(active: true).count
    @listing_count      = Listing.count
    @alert_count        = Alert.count
    @api_call_count     = SearchRun.count
    @api_today_count    = SearchRun.where(created_at: Time.now.all_day).count
    @last_activity      = Listing.maximum(:last_seen_at)
    @recent_listings    = Listing.includes(:search_run).order(updated_at: :desc).limit(10)
    @search_id_by_query = search_id_by_query
  end
end
