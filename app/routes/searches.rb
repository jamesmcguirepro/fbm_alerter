# frozen_string_literal: true

class MarketplaceApp < Sinatra::Base
  helpers do
    # Attributes submitted by the new/edit search forms. When the user typed a
    # location but has not picked a candidate (or has JavaScript off), resolve
    # the top match here so the normal form still works.
    def saved_search_attributes
      attributes = {
        query: params[:query],
        lat: params[:lat],
        long: params[:long],
        min_price: params[:min_price],
        max_price: params[:max_price],
        radius_mi: params[:radius_mi],
        condition: params[:condition],
        delivery_method: params[:delivery_method],
        email: params[:email],
        name: params[:name],
        resolved_location: params[:resolved_location]
      }

      place = lookup_submitted_location(attributes)
      return attributes unless place

      attributes.merge(lat: place.lat, long: place.long, resolved_location: place.name)
    end

    # A picked candidate already supplies coordinates; only look up free text.
    def lookup_submitted_location(attributes)
      return nil if attributes[:lat].present? && attributes[:long].present?

      query = params[:location_query].to_s.strip
      return nil if query.empty?

      Geocoder.search(query:, limit: 1).first
    end

    # Explain a failed lookup rather than only showing the bare coordinate
    # validation error. Nil when the user did not type a location at all.
    def location_lookup_error(record)
      return nil if record.lat.present? && record.long.present?

      query = params[:location_query].to_s.strip
      return nil if query.empty?

      "We couldn't find #{query}. Pick a match from the list or enter coordinates manually."
    end
  end

  get '/searches' do
    @show_inactive = params[:inactive] == '1'
    scope = SavedSearch.kept.order(created_at: :desc)
    scope = scope.where(active: true) unless @show_inactive
    @searches = scope.all
    # Best-effort backfill of cached place names. Resolve at most one per page
    # load so a batch of legacy rows cannot stall the page or burst Nominatim;
    # new searches get their name from the location picker when saved.
    @searches.find { |search| search.resolved_location.blank? }&.resolve_location!
    erb :'searches/index'
  end

  get '/searches/new' do
    @search = SavedSearch.new
    @location_query = ''
    erb :'searches/new'
  end

  post '/searches' do
    search = SavedSearch.new(saved_search_attributes.merge(active: true))

    if search.save
      redirect '/searches'
    else
      @search = search
      @location_query = params[:location_query].to_s
      error = location_lookup_error(search)
      search.errors.add(:base, error) if error
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
    attributes = saved_search_attributes.merge(active: params[:active] == 'on')
    replacement = SavedSearch.new(attributes)

    if replacement.save
      original.update_column(:active, false)
      redirect '/searches'
    else
      # Re-render with the entered values and errors, without saving anything.
      @search = original
      @search.assign_attributes(attributes)
      @location_query = params[:location_query].to_s
      @search.valid?
      error = location_lookup_error(@search)
      @search.errors.add(:base, error) if error
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

    erb :'searches/_row', layout: false, locals: { search: }
  end
end
