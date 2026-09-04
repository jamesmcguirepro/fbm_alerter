# frozen_string_literal: true

# Email service for sending alert notifications
class EmailService
  class << self
    # Configure SMTP settings
    def configure_smtp
      Mail.defaults do
        delivery_method :smtp, {
          address: Config.smtp_address,
          port: Config.smtp_port,
          user_name: Config.smtp_username,
          password: Config.smtp_password,
          authentication: 'plain',
          enable_starttls_auto: true
        }
      end
    end

    # Send alert emails for new listings
    # @param listings [Array<Hash>] Array of listing hashes from database
    def send_alerts(listings)
      return if listings.empty?

      configure_smtp

      subject = "🔔 #{listings.length} New Marketplace Listing(s)"
      html_body = build_html_email(listings)

      Config.email_to.each do |recipient|
        send_to_recipient(recipient, subject, html_body)
      end
    end

    private

    # Send email to a single recipient
    def send_to_recipient(recipient, subject, html_body)
      mail = Mail.new do
        from Config.email_from
        to recipient
        subject subject
        html_part do
          content_type 'text/html; charset=UTF-8'
          body html_body
        end
      end

      mail.deliver!
      puts "✓ Email sent to #{recipient}"
    rescue StandardError => e
      puts "✗ Failed to send email to #{recipient}: #{e.message}"
    end

    # Build HTML email body
    def build_html_email(listings)
      html = build_email_header(listings.length)

      listings.each do |listing|
        html += build_listing_section(listing)
      end

      html += build_email_footer
      html
    end

    # Email header HTML
    def build_email_header(count)
      <<~HTML
        <html>
          <head>
            <style>
              body { font-family: Arial, sans-serif; background: #f5f5f5; }
              .container { max-width: 800px; margin: 20px auto; background: white; padding: 20px; border-radius: 8px; }
              .header { color: #333; border-bottom: 2px solid #007bff; padding-bottom: 10px; }
              .listing { border: 1px solid #ddd; margin: 15px 0; padding: 15px; border-radius: 4px; }
              .listing:hover { background: #f9f9f9; }
              .title { font-size: 18px; font-weight: bold; color: #007bff; margin: 10px 0; }
              .price { font-size: 24px; font-weight: bold; color: #28a745; }
              .location { color: #666; font-size: 14px; }
              .image { max-width: 100%; height: auto; margin: 10px 0; border-radius: 4px; }
              .link { display: inline-block; margin-top: 10px; padding: 8px 16px; background: #007bff; color: white; text-decoration: none; border-radius: 4px; }
              .link:hover { background: #0056b3; }
              .query { background: #f0f0f0; padding: 5px 10px; border-radius: 3px; font-size: 12px; color: #666; display: inline-block; margin: 5px 0; }
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
    def build_listing_section(listing)
      image_html = listing['image_url'] ? %(<img src="#{listing['image_url']}" class="image" />) : ''
      price_display = listing['price'] ? "$#{listing['price'].round(2)}" : 'N/A'

      <<~HTML
        <div class="listing">
          <span class="query">#{listing['search_query']}</span>
          #{image_html}
          <div class="title">#{listing['title']}</div>
          <div class="price">#{price_display}</div>
          <div class="location">📍 #{listing['location']}</div>
          <a href="#{listing['url']}" class="link" target="_blank">View Listing</a>
          <div style="font-size: 12px; color: #999; margin-top: 10px;">
            Listed: #{listing['first_seen_at']}
          </div>
        </div>
      HTML
    end

    # Email footer HTML
    def build_email_footer
      <<~HTML
              <div style="text-align: center; margin-top: 30px; padding-top: 20px; border-top: 1px solid #ddd; color: #666; font-size: 12px;">
                <p>Marketplace Monitor • Automated Email Alert</p>
              </div>
            </div>
          </body>
        </html>
      HTML
    end
  end
end
