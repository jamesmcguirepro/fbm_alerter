# frozen_string_literal: true

class MarketplaceApp < Sinatra::Base
  get '/searches' do
    @show_inactive = params[:inactive] == '1'
    scope = SavedSearch.kept.order(created_at: :desc)
    scope = scope.where(active: true) unless @show_inactive
    @searches = scope.to_a

    # Best-effort backfill of cached place names. Resolve at most one per page
    # load so a batch of legacy rows cannot stall the page or burst Nominatim;
    # new searches get their name from the location picker when saved.
    @searches.find { |search| search.resolved_location.blank? }&.resolve_location!

    ids = @searches.map(&:id)
    @call_counts = ids.empty? ? {} : SearchRun.where(saved_search_id: ids).group(:saved_search_id).count
    @last_call_at = ids.empty? ? {} : SearchRun.where(saved_search_id: ids).group(:saved_search_id).maximum(:created_at)

    erb :'searches/index'
  end

  get '/searches/new' do
    @search = SavedSearch.new
    @location_query = ''
    erb :'searches/new'
  end

  post '/searches' do
    form = SearchForm.new(params)
    search = form.build(active: true)

    if search.save
      redirect '/searches'
    else
      @search = search
      @location_query = form.location_query
      form.add_location_error(search)
      status 422
      erb :'searches/new'
    end
  end

  get '/searches/:id/edit' do
    @search = SavedSearch.find(params[:id])
    @location_query = @search.resolved_location.to_s
    erb :'searches/edit'
  end

  # Saved searches are immutable: editing forks a new search and pauses the
  # original, so listings keep pointing at the search that actually found them.
  patch '/searches/:id' do
    original = SavedSearch.find(params[:id])
    form = SearchForm.new(params)
    replacement = form.build(active: params[:active] == 'on')

    if replacement.save
      original.update_column(:active, false)
      redirect '/searches'
    else
      # Re-render with the entered values and errors, without saving anything.
      @search = original
      @search.assign_attributes(form.attributes)
      @location_query = form.location_query
      @search.valid?
      form.add_location_error(@search)
      status 422
      erb :'searches/edit'
    end
  end

  # Candidate list for the location picker. Only called when the user presses
  # Find: Nominatim forbids autocomplete/search-as-you-type.
  get '/locations/search' do
    @query = params[:location_query].to_s.strip
    @places = @query.empty? ? [] : Geocoder.search(query: @query)
    erb :'searches/_location_results', layout: false
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

    erb :'searches/_row', layout: false, locals: { search:, call_counts: {}, last_call_at: {} }
  end
end
