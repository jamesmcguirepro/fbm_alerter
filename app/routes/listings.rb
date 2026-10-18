# frozen_string_literal: true

class MarketplaceApp < Sinatra::Base
  get '/listings' do
    query = Listing.all.includes(:search_run)

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
