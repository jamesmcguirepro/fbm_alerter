# frozen_string_literal: true

class MarketplaceApp < Sinatra::Base
  get '/listings' do
    query = Listing.all.includes(:search_run)

    @search_id = params[:search_id].to_s.strip.presence
    if @search_id
      @search = SavedSearch.find_by(id: @search_id)
      # Alert rows double as the per-search result history for now: every
      # listing newly returned by a saved search gets one.
      query = if @search
                query.where(id: Alert.where(search_id: @search.id).select(:listing_id))
              else
                query.none
              end
    end

    if params[:query].to_s.strip != ''
      # ILIKE is Postgres, not SQLite; LIKE is already case-insensitive for
      # ASCII, so a plain substring match behaves the way users expect here.
      query = query.where('title LIKE ?', "%#{params[:query]}%")
    end

    if params[:sold] == '1'
      query = query.where(is_sold: true)
    elsif params[:sold] == '0'
      query = query.where(is_sold: false)
    end

    query = query.order(updated_at: :desc)

    page = [params[:page].to_i, 1].max
    per_page = 25
    offset = (page - 1) * per_page

    @listings = query.offset(offset).limit(per_page)
    @total = query.count
    @total_pages = (@total.to_f / per_page).ceil
    @page = page
    @query = params[:query].to_s
    @sold = params[:sold]

    # Map a listing's stored query string to a saved search, so the listings
    # view can link back to the search that produced it.
    @search_id_by_query = search_id_by_query

    erb :'listings/index'
  end
end
