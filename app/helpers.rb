# frozen_string_literal: true

require 'cgi'

module ViewHelpers
  # Curated short list — easy to scan. Value is an IANA zone name; add more
  # here if you need them. Defaults to Pacific.
  TIME_ZONES = [
    ['America/Los_Angeles', 'Pacific (PT)'],
    ['America/Denver', 'Mountain (MT)'],
    ['America/Chicago', 'Central (CT)'],
    ['America/New_York', 'Eastern (ET)'],
    ['UTC', 'UTC']
  ].freeze

  DEFAULT_TIME_ZONE = 'America/Los_Angeles'

  # The zone chosen in the dropdown (falls back to the default).
  def active_time_zone
    chosen = session[:time_zone].to_s
    TIME_ZONES.any? { |zone, _| zone == chosen } ? chosen : DEFAULT_TIME_ZONE
  end

  # Only ever bounce back into this app (never to an absolute or off-site URL).
  def back_to(path)
    path = path.to_s
    path.start_with?('/') && !path.start_with?('//') ? path : '/dashboard'
  end

  def escape_html(text)
    CGI.escapeHTML(text.to_s)
  end
  def format_price(value)
    PriceFormatter.format(value)
  end

  # Timestamps in the chosen time zone. `seconds: true` adds HH:MM:SS, for
  # screens where events within the same minute must be told apart.
  def format_date(value, seconds: false)
    return '—' if value.nil?

    pattern = seconds ? '%b %d, %Y %I:%M:%S %p %Z' : '%b %d, %Y %I:%M %p %Z'
    value.in_time_zone(active_time_zone).strftime(pattern)
  end

  def format_day(value)
    return '—' if value.nil?

    value.in_time_zone(active_time_zone).strftime('%b %d, %Y')
  end

  def format_coordinates(lat, long)
    return '—' if lat.nil? || long.nil?

    '%.4f, %.4f' % [lat.to_f, long.to_f]
  end

  def format_number(value)
    return '—' if value.nil?

    ActiveSupport::NumberHelper.number_to_delimited(value)
  end

  # Warn on the dashboard once the balance gets tight (≈50 searches left).
  CREDITS_LOW = 50

  def low_credits?(credits)
    !credits.nil? && credits.to_i < CREDITS_LOW
  end

  # API-call count for a saved search, rendered on its own (used inline in the
  # table and again for the htmx out-of-band swap after a manual run).
  def calls_cell(search)
    count = search.search_runs.count
    last = search.search_runs.maximum(:created_at)

    %(<div class="calls-count">#{count}</div>) +
      %(<div class="muted">#{last ? "last #{format_day(last)}" : 'never run'}</div>)
  end

  def truncate(text, length: 40)
    return '' if text.nil?

    text.length > length ? "#{text[0, length - 3]}..." : text
  end

  def active_badge(search)
    if search.active
      '<span class="badge badge--active">Active</span>'
    else
      '<span class="badge badge--paused">Paused</span>'
    end
  end

  def run_monitor_capture
    output = StringIO.new
    monitor = MarketplaceMonitor.new(io: output)
    yield monitor
    output.string
  rescue StandardError => e
    "✗ Error: #{e.message}\n"
  end

  def search_link(search)
    "/searches/#{search.id}"
  end

  # Map a listing's stored query string back to a saved search id, so a listing
  # row can link to the search that produced it (earliest search wins).
  def search_id_by_query
    SavedSearch.order(:created_at).pluck(:query, :id).each_with_object({}) do |(query, id), map|
      map[query] ||= id
    end
  end

  # A query label that links to the search's row on the searches page (paused
  # searches included, hence `inactive=1`). Falls back to plain text when the
  # search is unknown — e.g. a deleted search, or an ad-hoc CLI run.
  def search_query_link(search_id, query)
    label = escape_html(truncate(query))
    return label if search_id.nil?

    %(<a href="/searches?inactive=1#search-row-#{search_id}">#{label}</a>)
  end

  def image_tag(url, alt)
    return '' if url.nil? || url.empty?

    %(<img src="#{escape_html(url)}" alt="#{escape_html(alt)}" class="thumb">)
  end

  # Wrap content in an external link when a URL is present, otherwise return it as-is.
  def external_link(url, content)
    return content if url.nil? || url.to_s.strip.empty?

    %(<a href="#{escape_html(url)}" target="_blank" rel="noopener">#{content}</a>)
  end

  def mask(str)
    return '—' if str.nil? || str.empty?

    str.length > 10 ? "#{str[0, 7]}#{'*' * (str.length - 10)}#{str[-3, 3]}" : ('*' * str.length)
  end

  # Render validation errors for a record as an HTML block ('' when valid).
  def form_errors(record)
    return '' if record.nil? || record.errors.empty?

    items = record.errors.full_messages.map { |m| "<li>#{escape_html(m)}</li>" }.join
    %(<div class="form-errors"><strong>Please fix the following:</strong><ul>#{items}</ul></div>)
  end

  def qs_extra
    parts = []
    parts << "query=#{CGI.escape(@query)}" if @query.to_s.strip != ''
    parts << "sold=#{@sold}" if @sold.to_s.strip != ''
    parts.empty? ? '' : "&#{parts.join('&')}"
  end
end
