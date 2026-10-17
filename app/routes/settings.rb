# frozen_string_literal: true

class MarketplaceApp < Sinatra::Base
  helpers ViewHelpers

  helpers do
    # Recent listings from the database, ready for the email template. Falls
    # back to sample data so the preview always renders something. No external
    # API is called, so previewing never spends SociaVault credits.
    def preview_listings
      recent = Listing.order(last_seen_at: :desc).limit(3).map { |listing| to_listing_object(listing) }
      recent.empty? ? sample_listings : recent
    end

    def to_listing_object(listing)
      ListingObject.new(
        listing_id: listing.listing_id,
        title: listing.title,
        price: listing.price,
        location: listing.location,
        url: listing.url,
        image_url: listing.image_url,
        search_query: listing.search_query,
        first_seen_at: listing.first_seen_at,
        last_seen_at: listing.last_seen_at,
        is_sold: listing.is_sold
      )
    end

    # A couple of sample listings (one complete, one sparse) used when the
    # database has no listings yet.
    def sample_listings
      now = Time.current

      [
        ListingObject.new(
          listing_id: 'sample-1', title: 'Vintage Road Bike — 54cm',
          price: 1250, location: 'Santa Barbara, CA',
          url: 'https://facebook.com/marketplace/item/sample-1/',
          image_url: nil, search_query: 'road bike',
          first_seen_at: now, last_seen_at: now, is_sold: false
        ),
        ListingObject.new(
          listing_id: 'sample-2', title: 'Mid-century Coffee Table',
          price: nil, location: nil,
          url: 'https://facebook.com/marketplace/item/sample-2/',
          image_url: nil, search_query: 'furniture',
          first_seen_at: now, last_seen_at: now, is_sold: false
        )
      ]
    end
  end

  get '/settings' do
    erb :settings
  end

  # Render the alert email in the browser so its layout can be iterated on
  # without sending mail or running any searches.
  get '/settings/email-preview' do
    content_type 'text/html'
    EmailService.render(listings: preview_listings)
  end

  post '/settings/test-email' do
    to = params[:email].to_s.strip

    if to.empty?
      session[:flash_error] = 'Please provide a recipient email address.'
    else
      begin
        listings = preview_listings
        Mailer.send_email(
          to:,
          from: Config.email_from,
          subject: "🔔 #{listings.length} New Marketplace Listing(s) (test)",
          html_body: EmailService.render(listings:)
        )
        session[:flash] = "Test email sent to #{to}."
      rescue StandardError => e
        session[:flash_error] = "Failed to send test email: #{e.message}"
      end
    end

    redirect '/settings'
  end
end
