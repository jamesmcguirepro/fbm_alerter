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
    def send_alerts(listings:, emails:, query:)
      return if listings.empty?

      html_body = render(listings:, query:)
      subject = subject_line(count: listings.length, query:)

      emails.each do |recipient|
        send_to_recipient(recipient:, subject:, html_body:)
      end
    end

    # Build the full alert email HTML. Public so it can be rendered for a
    # preview without sending (and without spending any API credits).
    # @param listings [Array<ListingObject>]
    # @param query [String] the search query the listings matched
    # @return [String]
    def render(listings:, query:)
      html = header(count: listings.length, query:)
      listings.each_with_index do |listing, index|
        html += listing_section(listing:, alternate: index.odd?)
      end
      html + footer
    end

    # Subject line naming the search query and the number of matches.
    # @return [String]
    def subject_line(count:, query:)
      "🔔 #{count} new listing#{'s' if count != 1} for \"#{query}\""
    end

    private

    # Send email to a single recipient
    def send_to_recipient(recipient:, subject:, html_body:)
      Mailer.send_email(to: recipient, from: Config.email_from, subject:, html_body:)

      puts "✓ Email sent to #{recipient}"
    rescue StandardError => e
      puts "✗ Failed to send email to #{recipient}: #{e.message}"
    end

    # Email header HTML, led by the search query and match count
    def header(count:, query:)
      <<~HTML
        <!DOCTYPE html>
        <html>
          <head>
            <meta charset="UTF-8">
            <style>
              body { font-family: Arial, sans-serif; background: #f5f5f5; margin: 0; padding: 20px 0; }
              .container { max-width: 600px; margin: 0 auto; background: #fff; padding: 20px; border-radius: 8px; }
              .header { color: #111827; border-bottom: 2px solid #007bff; padding-bottom: 10px; margin-bottom: 12px; }
              .header h1 { margin: 0 0 6px; font-size: 22px; }
              .header p { margin: 0; color: #6b7280; }
              .listing { display: block; padding: 14px; border-radius: 6px; text-decoration: none; color: #111827; margin-bottom: 8px; }
              .listing.alt { background: #f1f3f5; }
              .thumb { width: 96px; height: 96px; object-fit: cover; border-radius: 6px; float: left; margin-right: 14px; }
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
                <h1>#{escape(query)}</h1>
                <p>#{count} new listing#{'s' if count != 1}</p>
              </div>
      HTML
    end

    # Build HTML for a single listing. The whole card links to the ad.
    def listing_section(listing:, alternate: false)
      classes = "listing#{' alt' if alternate}"
      body = image_html(listing) +
             %(<div class="title">#{escape(listing.title)}</div>) +
             location_html(listing) +
             %(<div class="price">#{PriceFormatter.format(listing.price)}</div>) +
             listed_html(listing) +
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
    def footer
      <<~HTML
              <div style="text-align: center; margin-top: 30px; padding-top: 20px; border-top: 1px solid #ddd; color: #666; font-size: 12px;">
                <p>Marketplace Monitor • Automated Email Alert</p>
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
    # date shown in the email matches the reader's local date.
    def format_time(value)
      return nil if value.nil?
      return value.to_s unless value.respond_to?(:getlocal)

      value.getlocal.strftime('%b %d, %Y')
    end
  end
end
