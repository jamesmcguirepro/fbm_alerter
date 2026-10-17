# frozen_string_literal: true

# Formats a numeric price as US currency with thousands separators.
module PriceFormatter
  module_function

  # @param value [Numeric, nil]
  # @return [String] e.g. "$1,234.50", "$2,000", or "N/A" when nil
  def format(value)
    return 'N/A' if value.nil?

    dollars = value.to_f
    ActiveSupport::NumberHelper.number_to_currency(
      dollars, precision: dollars == dollars.to_i ? 0 : 2
    )
  end
end
