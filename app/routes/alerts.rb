# frozen_string_literal: true

class MarketplaceApp < Sinatra::Base
  helpers ViewHelpers

  get '/alerts' do
    page = [params[:page].to_i, 1].max
    per_page = 50
    offset = (page - 1) * per_page

    @alerts = Alert.joins(:listing, :saved_search)
                   .order(sent_at: :desc)
                   .offset(offset)
                   .limit(per_page)
    @total = Alert.count
    @total_pages = (@total.to_f / per_page).ceil
    @page = page

    erb :'alerts/index'
  end
end
