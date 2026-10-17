# frozen_string_literal: true

require 'cgi'

module ViewHelpers
  def escape_html(text)
    CGI.escapeHTML(text.to_s)
  end
  def format_price(value)
    return 'N/A' if value.nil?

    "$#{value.to_f.round(2)}"
  end

  def format_date(value)
    return '—' if value.nil?

    value.strftime('%b %d, %Y %I:%M %p')
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

  def image_tag(url, alt)
    return '' if url.nil? || url.empty?

    %(<img src="#{escape_html(url)}" alt="#{escape_html(alt)}" class="thumb">)
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
