# frozen_string_literal: true

class MarketplaceApp < Sinatra::Base
  helpers ViewHelpers

  get '/searches' do
    @searches = SavedSearch.order(created_at: :desc).all
    erb :'searches/index'
  end

  get '/searches/new' do
    @search = SavedSearch.new
    erb :'searches/new'
  end

  post '/searches' do
    search = SavedSearch.new(
      query: params[:query],
      lat: params[:lat],
      long: params[:long],
      min_price: params[:min_price],
      max_price: params[:max_price],
      radius_km: params[:radius_km],
      condition: params[:condition],
      delivery_method: params[:delivery_method],
      email: params[:email],
      name: params[:name],
      active: true
    )

    if search.save
      redirect '/searches'
    else
      @search = search
      status 422
      erb :'searches/new'
    end
  end

  get '/searches/:id/edit' do
    @search = SavedSearch.find(params[:id])
    erb :'searches/edit'
  end

  patch '/searches/:id' do
    search = SavedSearch.find(params[:id])
    search.update(
      query: params[:query],
      lat: params[:lat],
      long: params[:long],
      min_price: params[:min_price],
      max_price: params[:max_price],
      radius_km: params[:radius_km],
      condition: params[:condition],
      delivery_method: params[:delivery_method],
      email: params[:email],
      name: params[:name],
      active: params[:active] == 'on'
    )

    if search.save
      redirect '/searches'
    else
      @search = search
      status 422
      erb :'searches/edit'
    end
  end

  # htmx deletes the row via outerHTML swap, so return an empty body (not a redirect).
  delete '/searches/:id' do
    monitor = MarketplaceMonitor.new(io: StringIO.new)
    monitor.remove_saved_search(id: params[:id])
    status 200
    body ''
  end

  post '/searches/:id/run' do
    @log = run_monitor_capture do |monitor|
      monitor.run_single(id: params[:id])
    end

    @search = SavedSearch.find(params[:id])
    erb :'searches/_run_log', layout: false
  end

  # Return the re-rendered row so htmx can swap it in place.
  post '/searches/:id/toggle' do
    search = SavedSearch.find(params[:id])
    search.update(active: !search.active)

    erb :'searches/_row', layout: false, locals: { search: }
  end
end
