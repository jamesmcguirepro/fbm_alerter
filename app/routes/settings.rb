# frozen_string_literal: true

class MarketplaceApp < Sinatra::Base
  helpers do
    # Recent listings from a single search, ready for the email template.
    # Falls back to sample data so the preview always renders something. No
    # external API is called, so previewing never spends SociaVault credits.
    def preview_email
      recent = Listing.order(last_seen_at: :desc).first
      return preview_payload(listings: sample_listings, query: 'road bike') if recent.nil?

      listings = Listing.where(search_query: recent.search_query)
                        .order(last_seen_at: :desc)
                        .limit(4)
                        .map { |listing| to_listing_object(listing) }
      query = recent.search_query.presence || 'your search'

      preview_payload(
        listings:,
        query:,
        saved_search: SavedSearch.kept.find_by(query: recent.search_query)
      )
    end

    # Adds sample API counts and a real (or representative) Marketplace link so
    # the preview shows every part of the alert email.
    def preview_payload(listings:, query:, saved_search: nil)
      price_range = if saved_search&.min_price || saved_search&.max_price
                      parts = []
                      parts << "$#{saved_search.min_price.to_i}" if saved_search.min_price
                      parts << "$#{saved_search.max_price.to_i}" if saved_search.max_price
                      "between #{parts.join(' and ')}"
                    end

      {
        listings:,
        query:,
        stats: { api_results: listings.length + 15, filtered: 15, credits_used: 1, exact_matches: listings.length },
        subject: EmailService.subject_line(count: listings.length, query:, exact_count: listings.length),
        search_url: saved_search&.marketplace_url || SavedSearch.new(query:).marketplace_url,
        location_label: saved_search&.location_label,
        price_range:,
        radius_km: saved_search&.radius_km || 65,
        exact_count: listings.length
      }
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
        listed_at: listing.listed_at,
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
          listed_at: now, first_seen_at: now, last_seen_at: now, is_sold: false
        ),
        ListingObject.new(
          listing_id: 'sample-2', title: 'Mid-century Coffee Table',
          price: nil, location: nil,
          url: 'https://facebook.com/marketplace/item/sample-2/',
          image_url: nil, search_query: 'furniture',
          # No listed_at: exercises the "First seen" fallback in the preview.
          listed_at: nil, first_seen_at: now, last_seen_at: now, is_sold: false
        )
      ]
    end
  end

  get '/settings' do
    erb :settings
  end

  # Render the alert email in the browser so its layout can be iterated on
  # without sending mail or running any searches. The subject line is shown as
  # a banner above the email so it's visible at a glance while iterating.
  get '/settings/email-preview' do
    content_type 'text/html'
    email = preview_email
    subject = Rack::Utils.escape_html(email.delete(:subject))
    html = EmailService.render(**email)
    # Insert the subject banner inside <body> so the result stays valid HTML.
    banner = %(<div style="background:#eef2ff;border:1px solid #c7cdfe;border-radius:6px;padding:10px 14px;margin-bottom:14px;font-size:14px;color:#1f2933;"><strong>Subject:</strong> #{subject}</div>)
    html.sub(%r{<body>}, "<body>\n#{banner}")
  end

  post '/settings/test-email' do
    to = params[:email].to_s.strip

    if to.empty?
      session[:flash_error] = 'Please provide a recipient email address.'
    else
      begin
        email = preview_email
        email.delete(:subject)
        Mailer.send_email(
          to:,
          from: Config.email_from,
          subject: "#{EmailService.subject_line(count: email[:listings].length, query: email[:query])} (test)",
          html_body: EmailService.render(**email)
        )
        session[:flash] = "Test email sent to #{to}."
      rescue StandardError => e
        session[:flash_error] = "Failed to send test email: #{e.message}"
      end
    end

    redirect '/settings'
  end
end
