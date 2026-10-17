# frozen_string_literal: true

class MarketplaceApp < Sinatra::Base
  helpers ViewHelpers

  get '/listings' do
    query = Listing.all.includes(:search_run)

    if params[:query].to_s.strip != ''
      query = query.where('title ILIKE ?', "%#{params[:query]}%")
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
    @search_id_by_query = SavedSearch.order(:created_at).pluck(:query, :id).each_with_object({}) do |(saved_query, id), map|
      map[saved_query] ||= id
    end

    erb :'listings/index'
  end
end
