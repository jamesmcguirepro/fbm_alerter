# frozen_string_literal: true

class MarketplaceApp < Sinatra::Base
  helpers ViewHelpers

  helpers do
    # Attributes submitted by the new/edit search forms.
    def saved_search_attributes
      {
        query: params[:query],
        lat: params[:lat],
        long: params[:long],
        min_price: params[:min_price],
        max_price: params[:max_price],
        radius_km: params[:radius_km],
        condition: params[:condition],
        delivery_method: params[:delivery_method],
        email: params[:email],
        name: params[:name]
      }
    end
  end

  get '/searches' do
    @show_inactive = params[:inactive] == '1'
    scope = SavedSearch.kept.order(created_at: :desc)
    scope = scope.where(active: true) unless @show_inactive
    @searches = scope.all
    # Best-effort backfill of cached place names; each is looked up only once.
    @searches.each(&:resolve_location!)
    erb :'searches/index'
  end

  get '/searches/new' do
    @search = SavedSearch.new
    erb :'searches/new'
  end

  post '/searches' do
    search = SavedSearch.new(saved_search_attributes.merge(active: true))

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

  # Saved searches are immutable: editing forks a new search and pauses the
  # original, so listings keep pointing at the search that actually found them.
  patch '/searches/:id' do
    original = SavedSearch.find(params[:id])
    attributes = saved_search_attributes.merge(active: params[:active] == 'on')
    replacement = SavedSearch.new(attributes)

    if replacement.save
      original.update_column(:active, false)
      redirect '/searches'
    else
      # Re-render with the entered values and errors, without saving anything.
      @search = original
      @search.assign_attributes(attributes)
      @search.valid?
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
