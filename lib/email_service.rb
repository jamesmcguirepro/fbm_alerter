# frozen_string_literal: true

require 'cgi'
require 'socket'

# Email service for sending alert notifications
class EmailService
  class << self
    # Send alert emails for the new listings found by a single search.
    # @param listings [Array<ListingObject>] listings matched by this search
    # @param emails [Array<String>] recipient addresses
    # @param query [String] the search query these listings matched
    # @param stats [Hash, nil] api_results, filtered, credits_used and exact_matches
    # @param exact_count [Integer, nil] how many new listings contain every query keyword
    # @param search_url [String, nil] link that reruns the search on Marketplace
    # @param location_label [String, nil] place name or coordinates searched
    # @param price_range [String, nil] e.g. "$100 - $500"
    # @param radius_km [Integer, nil] search radius in kilometres
    def send_alerts(listings:, emails:, query:, stats: nil, exact_count: nil, search_url: nil,
                    location_label: nil, price_range: nil, radius_km: nil)
      return if listings.empty?

      html_body = render(
        listings:, query:, stats:, exact_count:, search_url:,
        location_label:, price_range:, radius_km:
      )
      subject = subject_line(count: listings.length, query:, exact_count:)

      emails.each do |recipient|
        send_to_recipient(recipient:, subject:, html_body:)
      end
    end

    # Build the full alert email HTML. Public so it can be rendered for a
    # preview without sending (and without spending any API credits).
    # @param listings [Array<ListingObject>]
    # @param query [String] the search query the listings matched
    # @param stats [Hash, nil] api_results, filtered, credits_used and exact_matches
    # @param exact_count [Integer, nil] how many new listings contain every query keyword
    # @param search_url [String, nil] link that reruns the search on Marketplace
    # @param location_label [String, nil] place name or coordinates searched
    # @param price_range [String, nil] e.g. "$100 - $500"
    # @param radius_km [Integer, nil] search radius in kilometres
    # @return [String]
    def render(listings:, query:, stats: nil, exact_count: nil, search_url: nil,
               location_label: nil, price_range: nil, radius_km: nil)
      html = header(
        count: listings.length, query:, stats:, exact_count:, search_url:,
        location_label:, price_range:, radius_km:
      )
      listings.each_with_index do |listing, index|
        html += listing_section(listing:, alternate: index.odd?)
      end
      html + footer(stats:)
    end

    # Subject line naming the search query, the number of matches and the exact
    # match count (every query keyword present in the title).
    # @return [String]
    def subject_line(count:, query:, exact_count: nil)
      exact = exact_count.nil? ? '' : " (#{exact_count} exact)"
      "🔔 #{count} new listing#{'s' if count != 1}#{exact} for \"#{query}\""
    end

    private

    # Send email to a single recipient
    def send_to_recipient(recipient:, subject:, html_body:)
      Mailer.send_email(to: recipient, from: Config.email_from, subject:, html_body:)

      puts "✓ Email sent to #{recipient}"
    rescue StandardError => e
      puts "✗ Failed to send email to #{recipient}: #{e.message}"
    end

    # Email header HTML, led by the "Found N listings" summary line.
    def header(count:, query:, stats: nil, exact_count: nil, search_url: nil,
               location_label: nil, price_range: nil, radius_km: nil)
      exact_count = 0 if exact_count.nil?

      # Lead line: Found N new listing(s) (M exact) between $min and $max for "query"
      lead = "Found #{count} new listing#{'s' if count != 1} (#{exact_count} exact)"
      lead << " #{escape(price_range)}" if price_range
      lead << %( for "#{escape(query)}")

      # Location line: 📍450 km radius of Santa Barbara, California
      location_line = if location_label || radius_km
        parts = []
        parts << "📍#{radius_km} km radius" if radius_km
        parts << "of #{escape(location_label)}" if location_label
        parts.join(' ')
      end

      # Results line: Marketplace returned 19 results | 15 filtered out as not relevant
      results_line = if stats && !stats[:api_results].nil?
        results = stats[:api_results].to_i
        filtered = stats[:filtered].to_i
        %(<p class="results">Marketplace returned #{results} #{results == 1 ? 'result' : 'results'} | #{filtered} filtered out as not relevant</p>)
      end

      <<~HTML
        <!DOCTYPE html>
        <html>
          <head>
            <meta charset="UTF-8">
            <style>
              body { font-family: Arial, sans-serif; background: #f5f5f5; margin: 0; padding: 20px 0; }
              .container { max-width: 600px; margin: 0 auto; background: #fff; padding: 20px; border-radius: 8px; }
              .header { color: #111827; border-bottom: 2px solid #007bff; padding-bottom: 10px; margin-bottom: 12px; }
              .header h1 { margin: 0 0 8px; font-size: 18px; }
              .header .search-location { margin: 0 0 12px; font-size: 13px; color: #6b7280; }
              .header .results { margin: 0; font-size: 13px; color: #6b7280; }
              .header .search-link { display: inline-block; margin-top: 10px; color: #007bff; font-size: 14px; font-weight: bold; text-decoration: none; }
              .listing { display: block; padding: 14px; border-radius: 6px; text-decoration: none; color: #111827; margin-bottom: 8px; }
              .listing.alt { background: #f1f3f5; }
              .thumb { width: 96px; height: 96px; object-fit: cover; border-radius: 6px; float: left; margin-right: 14px; }
              .listing-body--with-thumb { margin-left: 110px; }
              .title { font-size: 17px; font-weight: bold; color: #111827; }
              .location { color: #4b5563; font-size: 15px; margin-top: 4px; }
              .price { font-size: 18px; font-weight: bold; color: #16a34a; margin-top: 6px; }
              .listed { font-size: 12px; color: #9ca3af; margin-top: 6px; }
              .clear { clear: both; }
            </style>
          </head>
          <body>
            <div class="container">
              <div class="header">
                <h1>#{lead}</h1>
                #{location_line && %(<p class="search-location">#{location_line}</p>)}
                #{results_line}
                #{search_link_html(search_url:)}
              </div>
      HTML
    end

    # Link that opens the same query, place and filters on Facebook Marketplace.
    def search_link_html(search_url:)
      return '' if search_url.to_s.strip.empty?

      %(<a class="search-link" href="#{escape(search_url)}" target="_blank">View this search on Facebook Marketplace →</a>)
    end

    # Build HTML for a single listing. The whole card links to the ad.
    def listing_section(listing:, alternate: false)
      classes = "listing#{' alt' if alternate}"
      image = image_html(listing)
      # Keep every text row in its own column beside the thumbnail. Without
      # this, a title tall enough to pass the floated image lets the metadata
      # (including the listed date) drop to the card's left edge underneath it.
      body_class = image.empty? ? 'listing-body' : 'listing-body listing-body--with-thumb'
      body = image +
             %(<div class="#{body_class}">) +
             %(<div class="title">#{escape(listing.title)}</div>) +
             location_html(listing) +
             %(<div class="price">#{PriceFormatter.format(listing.price)}</div>) +
             listed_html(listing) +
             %(</div>) +
             %(<div class="clear"></div>)

      if listing.url.to_s.strip.empty?
        %(<div class="#{classes}">#{body}</div>)
      else
        %(<a class="#{classes}" href="#{escape(listing.url)}" target="_blank">#{body}</a>)
      end
    end

    def image_html(listing)
      return '' if listing.image_url.to_s.strip.empty?

      %(<img class="thumb" src="#{escape(listing.image_url)}" alt="" width="96" height="96">)
    end

    def location_html(listing)
      return '' if listing.location.to_s.strip.empty?

      %(<div class="location">📍 #{escape(listing.location)}</div>)
    end

    # When the ad was listed on Marketplace, falling back to when we first saw
    # it for rows stored before listed_at existed. The label says which, so the
    # email never claims a listing date we don't actually know.
    def listed_html(listing)
      listed = format_time(listing.listed_at)
      return %(<div class="listed">Listed: #{listed}</div>) if listed

      seen = format_time(listing.first_seen_at)
      return '' unless seen

      %(<div class="listed">First seen: #{seen}</div>)
    end

    # Email footer HTML, ending with the host that sent it so alerts from
    # different machines can be told apart. The name comes from the container's
    # hostname, which compose sets (`hostname:`); a container's default hostname
    # is its container id, which changes on every recreate.
    def footer(stats: nil)
      credits = stats && stats[:credits_used]
      credit_line = if credits.nil?
                      ''
                    else
                      count = credits.to_i
                      "\n        <p>#{count} API credit#{'s' if count != 1} used for this search</p>"
                    end

      <<~HTML
              <div style="text-align: center; margin-top: 30px; padding-top: 20px; border-top: 1px solid #ddd; color: #666; font-size: 12px;">
                <p>Marketplace Monitor • Automated Email Alert</p>#{credit_line}
                <p>Sent by #{escape(Socket.gethostname)}</p>
              </div>
            </div>
          </body>
        </html>
      HTML
    end

    def escape(text)
      CGI.escapeHTML(text.to_s)
    end

    # Listing times come back from the API (and out of the database) as UTC.
    # `getlocal` converts them to the process time zone, which is set from TZ
    # in .env (and passed to the containers by docker-compose.yml), so the
    # date and time shown in the email match the reader's local clock.
    def format_time(value)
      return nil if value.nil?
      return value.to_s unless value.respond_to?(:getlocal)

      value.getlocal.strftime('%b %-d, %Y at %-l:%M %p')
    end
  end
end
