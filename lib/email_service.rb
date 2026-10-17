# frozen_string_literal: true

require 'cgi'

# Email service for sending alert notifications
class EmailService
  class << self
    # Send alert emails for new listings
    # @param listings [Array<ListingObject>] Array of listing objects
    # @param emails [Array<String>] List of email addresses to send to
    def send_alerts(listings:, emails:)
      return if listings.empty?

      subject = "🔔 #{listings.length} New Marketplace Listing(s)"
      html_body = render(listings:)

      emails.each do |recipient|
        send_to_recipient(recipient:, subject:, html_body:)
      end
    end

    # Build the full alert email HTML. Public so it can be rendered for a
    # preview without sending (and without spending any API credits).
    # @param listings [Array<ListingObject>]
    # @return [String]
    def render(listings:)
      html = header(count: listings.length)
      listings.each { |listing| html += listing_section(listing:) }
      html + footer
    end

    private

    # Send email to a single recipient
    def send_to_recipient(recipient:, subject:, html_body:)
      Mailer.send_email(to: recipient, from: Config.email_from, subject:, html_body:)

      puts "✓ Email sent to #{recipient}"
    rescue StandardError => e
      puts "✗ Failed to send email to #{recipient}: #{e.message}"
    end

    # Email header HTML
    def header(count:)
      <<~HTML
        <!DOCTYPE html>
        <html>
          <head>
            <meta charset="UTF-8">
            <style>
              body { font-family: Arial, sans-serif; background: #f5f5f5; margin: 0; }
              .container { max-width: 600px; margin: 20px auto; background: #fff; padding: 20px; border-radius: 8px; }
              .header { color: #333; border-bottom: 2px solid #007bff; padding-bottom: 10px; }
              .header h1 { margin: 0 0 6px; font-size: 20px; }
              .header p { margin: 0; color: #666; }
              .listing { border: 1px solid #ddd; margin: 15px 0; padding: 15px; border-radius: 4px; }
              .title { font-size: 18px; font-weight: bold; margin: 10px 0; }
              .title a { color: #007bff; text-decoration: none; }
              .price { font-size: 24px; font-weight: bold; color: #28a745; }
              .location { color: #666; font-size: 14px; margin-top: 4px; }
              .image { max-width: 100%; height: auto; margin: 10px 0; border-radius: 4px; }
              .link { display: inline-block; margin-top: 10px; padding: 8px 16px; background: #007bff; color: #fff; text-decoration: none; border-radius: 4px; }
              .query { background: #f0f0f0; padding: 5px 10px; border-radius: 3px; font-size: 12px; color: #666; display: inline-block; }
              .listed { font-size: 12px; color: #999; margin-top: 10px; }
            </style>
          </head>
          <body>
            <div class="container">
              <div class="header">
                <h1>🔔 New Marketplace Listings</h1>
                <p>Found #{count} new listing(s) matching your searches</p>
              </div>
      HTML
    end

    # Build HTML for a single listing
    # @param [ListingObject] listing
    def listing_section(listing:)
      <<~HTML
        <div class="listing">
          <span class="query">#{escape(listing.search_query)}</span>
          #{image_html(listing)}
          <div class="title">#{title_html(listing)}</div>
          <div class="price">#{PriceFormatter.format(listing.price)}</div>
          #{location_html(listing)}
          #{link_html(listing)}
          #{listed_html(listing)}
        </div>
      HTML
    end

    def image_html(listing)
      return '' if listing.image_url.to_s.strip.empty?

      %(<img src="#{escape(listing.image_url)}" class="image" alt="">)
    end

    def title_html(listing)
      title = escape(listing.title)
      return title if listing.url.to_s.strip.empty?

      %(<a href="#{escape(listing.url)}" target="_blank">#{title}</a>)
    end

    def location_html(listing)
      return '' if listing.location.to_s.strip.empty?

      %(<div class="location">📍 #{escape(listing.location)}</div>)
    end

    def link_html(listing)
      return '' if listing.url.to_s.strip.empty?

      %(<a href="#{escape(listing.url)}" class="link" target="_blank">View Listing</a>)
    end

    def listed_html(listing)
      date = format_time(listing.first_seen_at)
      return '' if date.nil?

      %(<div class="listed">Listed: #{date}</div>)
    end

    # Email footer HTML
    def footer
      <<~HTML
              <div style="text-align: center; margin-top: 30px; padding-top: 20px; border-top: 1px solid #ddd; color: #666; font-size: 12px;">
                <p>Marketplace Monitor • Automated Email Alert</p>
              </div>
            </div>
          </body>
        </html>
      HTML
    end

    def escape(text)
      CGI.escapeHTML(text.to_s)
    end

    def format_time(value)
      return nil if value.nil?
      return value.strftime('%b %-d, %Y') if value.respond_to?(:strftime)

      value.to_s
    end
  end
end
