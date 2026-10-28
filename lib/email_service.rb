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
    # @param radius_mi [Integer, nil] search radius in miles
    def send_alerts(listings:, emails:, query:, stats: nil, exact_count: nil, search_url: nil,
                    location_label: nil, price_range: nil, radius_mi: nil)
      return if listings.empty?

      html_body = render(
        listings:, query:, stats:, exact_count:, search_url:,
        location_label:, price_range:, radius_mi:
      )
      subject = subject_line(count: listings.length, query:, exact_count:)

      emails.each do |recipient|
        send_to_recipient(recipient:, subject:, html_body:)
      end
    end

    # Send a low-credit alert email. Renders a summary of the current balance,
    # the consumption trend, and a link to the SociaVault dashboard.
    def send_low_credit_alert
      current = CreditSnapshot.latest_recent
      days_remaining = CreditSnapshot.days_remaining

      send_to_recipient(
        recipient: Config.email_from,
        subject: '⚠ Marketplace Monitor — low credits alert',
        html_body: render_low_credit(current:, days_remaining:)
      )
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
    # @param radius_mi [Integer, nil] search radius in miles
    # @return [String]
    def render(listings:, query:, stats: nil, exact_count: nil, search_url: nil,
               location_label: nil, price_range: nil, radius_mi: nil)
      html = header(
        count: listings.length, query:, stats:, exact_count:, search_url:,
        location_label:, price_range:, radius_mi:
      )
      listings.each_with_index do |listing, index|
        html += listing_section(listing:, alternate: index.odd?)
      end
      html + footer(stats:)
    end

    # Build the low-credit alert HTML.
    # @param current [Integer, nil] current credit balance
    # @param days_remaining [Float, nil] projected days until exhaustion
    # @return [String]
    def render_low_credit(current:, days_remaining:)
      current_display = current.nil? ? 'unknown' : current.to_i
      days_display = days_remaining.nil? ? 'unknown' : "#{days_remaining} days"
      chart_data = credit_chart_data_json

      <<~HTML
        <!DOCTYPE html>
        <html>
          <head>
            <meta charset="UTF-8">
            <style>
              body { font-family: Arial, sans-serif; background: #f5f5f5; margin: 0; padding: 20px 0; }
              .container { max-width: 600px; margin: 0 auto; background: #fff; padding: 20px; border-radius: 8px; }
              .header { color: #111827; border-bottom: 2px solid #f59e0b; padding-bottom: 10px; margin-bottom: 12px; }
              .header h1 { margin: 0 0 8px; font-size: 18px; color: #b45309; }
              .stat { display: flex; justify-content: space-between; padding: 8px 0; border-bottom: 1px solid #f1f3f5; }
              .stat-label { color: #6b7280; }
              .stat-value { font-weight: bold; color: #111827; }
              .stat-value.danger { color: #dc2626; }
              .stat-value.warn { color: #f59e0b; }
              .chart { margin: 16px 0; text-align: center; }
              .chart canvas { max-width: 100%; }
              .footer { text-align: center; margin-top: 30px; padding-top: 20px; border-top: 1px solid #ddd; color: #666; font-size: 12px; }
              .footer a { color: #007bff; text-decoration: none; }
            </style>
          </head>
          <body>
            <div class="container">
              <div class="header">
                <h1>⚠ Credits running low</h1>
                <p style="margin: 0; color: #6b7280; font-size: 14px;">
                  Your credit balance is projected to run out in <strong>#{escape(days_display)}</strong>.
                  Please top up your plan at SociaVault.
                </p>
              </div>
              <div class="stat">
                <span class="stat-label">Current balance</span>
                <span class="stat-value #{current.nil? || current < 50 ? 'danger' : 'warn'}">#{escape(current_display.to_s)}</span>
              </div>
              <div class="stat">
                <span class="stat-label">Estimated days remaining</span>
                <span class="stat-value #{days_remaining.nil? || days_remaining < 7 ? 'danger' : 'warn'}">#{escape(days_display)}</span>
              </div>
              <div class="chart">
                <canvas id="credit-chart" width="560" height="200"></canvas>
                <script>
                  (function() {
                    var data = #{chart_data};
                    var canvas = document.getElementById('credit-chart');
                    if (!canvas || !data.length) return;
                    var ctx = canvas.getContext('2d');
                    var w = canvas.width, h = canvas.height;
                    var padding = { top: 20, right: 20, bottom: 30, left: 50 };
                    var chartW = w - padding.left - padding.right;
                    var chartH = h - padding.top - padding.bottom;
                    var balances = data.map(function(d) { return d[1]; });
                    var minBal = Math.min.apply(null, balances);
                    var maxBal = Math.max.apply(null, balances);
                    var range = maxBal - minBal || 1;
                    var stepX = chartW / (data.length - 1 || 1);
                    ctx.strokeStyle = '#007bff';
                    ctx.lineWidth = 2;
                    ctx.beginPath();
                    data.forEach(function(d, i) {
                      var x = padding.left + i * stepX;
                      var y = padding.top + chartH - ((d[1] - minBal) / range) * chartH;
                      if (i === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y);
                    });
                    ctx.stroke();
                    ctx.fillStyle = '#007bff';
                    data.forEach(function(d, i) {
                      var x = padding.left + i * stepX;
                      var y = padding.top + chartH - ((d[1] - minBal) / range) * chartH;
                      ctx.beginPath();
                      ctx.arc(x, y, 3, 0, 2 * Math.PI);
                      ctx.fill();
                    });
                    ctx.fillStyle = '#6b7280';
                    ctx.font = '11px Arial';
                    ctx.textAlign = 'right';
                    [minBal, maxBal].forEach(function(val, idx) {
                      var actualY = padding.top + chartH - ((val - minBal) / range) * chartH;
                      ctx.fillText(val.toFixed(0), padding.left - 5, actualY + 4);
                    });
                    ctx.textAlign = 'center';
                    var firstDate = new Date(data[0][0]);
                    var lastDate = new Date(data[data.length - 1][0]);
                    ctx.fillText(formatDate(firstDate), padding.left, h - 8);
                    ctx.fillText(formatDate(lastDate), w - padding.right, h - 8);
                  })();
                  function formatDate(d) {
                    var months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
                    return months[d.getMonth()] + ' ' + d.getDate();
                  }
                </script>
              </div>
              <div class="footer">
                <p>Marketplace Monitor v#{VERSION} • Credit Alert</p>
                <p><a href="https://sociavault.com/dashboard" target="_blank">Open SociaVault Dashboard →</a></p>
                <p>Sent by #{escape(Socket.gethostname)}</p>
              </div>
            </div>
          </body>
        </html>
      HTML
    end

    # JSON array of [ISO-8601 timestamp, balance] pairs for the chart.
    def credit_chart_data_json
      data = CreditSnapshot.chart_data
      return '[]' if data.empty?

      data.map { |ts, balance| "[#{ts.iso8601.inspect}, #{balance}]" }.to_s
    end
    private :credit_chart_data_json

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
               location_label: nil, price_range: nil, radius_mi: nil)
      exact_count = 0 if exact_count.nil?

      # Lead line: Found N new listing(s) (M exact) between $min and $max for "query"
      lead = "Found #{count} new listing#{'s' if count != 1} (#{exact_count} exact)"
      lead << " #{escape(price_range)}" if price_range
      lead << " for #{escape(query)}"

      # Location line: 📍450 mi radius of Santa Barbara, California
      location_line = if location_label || radius_mi
        parts = []
        parts << "📍#{radius_mi} mi radius" if radius_mi
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
                <p>Marketplace Monitor v#{VERSION} • Automated Email Alert</p>#{credit_line}
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
