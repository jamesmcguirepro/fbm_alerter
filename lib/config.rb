# frozen_string_literal: true

# Configuration management from environment variables
class Config
  class << self
    def api_key
      ENV['SOCIAVAULT_API_KEY'] || raise('SOCIAVAULT_API_KEY not set in .env')
    end

    def email_from
      ENV['EMAIL_FROM'] || 'marketplace-alerts@example.com'
    end

    def smtp_address
      ENV['SMTP_ADDRESS'] || 'smtp.gmail.com'
    end

    def smtp_port
      (ENV['SMTP_PORT'] || 587).to_i
    end

    def smtp_username
      ENV['SMTP_USERNAME']
    end

    def smtp_password
      ENV['SMTP_PASSWORD']
    end

    # When true, scrape calls become a no-op: the whole pipeline (UI, dashboard,
    # alert emails) can be exercised without spending a credit. Accepts the
    # usual truthy spellings, but `true`/`false` is the intended form. The
    # credit balance is still read for real, since that call is free.
    def dry_run?
      %w[1 true yes on].include?(ENV['DRY_RUN'].to_s.strip.downcase)
    end

    # Windows SociaVault accepts for date_listed, from its Marketplace search
    # endpoint. These are the API's documented values, not our own scheme.
    DATE_LISTED_VALUES = %w[all 1 7 30 last_24_hours last_7_days last_30_days].freeze
    DATE_LISTED_DEFAULT = 'last_7_days'

    # How far back each search looks. Unset means DATE_LISTED_DEFAULT; a typo
    # warns and falls back rather than failing a run, since the API rejects
    # unknown windows and a bad value here would break every search.
    def date_listed
      value = ENV['DATE_LISTED'].to_s.strip
      return DATE_LISTED_DEFAULT if value.empty?
      return value if DATE_LISTED_VALUES.include?(value)

      warn "⚠ DATE_LISTED=#{value.inspect} is not a SociaVault window. " \
           "Expected one of: #{DATE_LISTED_VALUES.join(', ')} (or leave it unset). " \
           "Using #{DATE_LISTED_DEFAULT}."
      DATE_LISTED_DEFAULT
    end

    # Daily run time for the scheduler, in the container's time zone. 24-hour
    # HH:MM; a typo falls back to the default rather than stopping the scheduler.
    SCHEDULE_AT_DEFAULT = '20:00'
    SCHEDULE_AT_PATTERN = /\A([01]?\d|2[0-3]):([0-5]\d)\z/

    def schedule_at
      value = ENV['SCHEDULE_AT'].to_s.strip
      return SCHEDULE_AT_DEFAULT if value.empty?

      match = SCHEDULE_AT_PATTERN.match(value)
      return format('%02d:%02d', match[1].to_i, match[2].to_i) if match

      warn "⚠ SCHEDULE_AT=#{value.inspect} is not a valid HH:MM time. " \
           "Using #{SCHEDULE_AT_DEFAULT}."
      SCHEDULE_AT_DEFAULT
    end

    # Validate configuration
    def validate!
      errors = []
      errors << 'SOCIAVAULT_API_KEY not set' unless ENV['SOCIAVAULT_API_KEY']

      return unless errors.any?

      puts 'Configuration errors:'
      errors.each { |e| puts "  - #{e}" }
      raise 'Invalid configuration'
    end
  end
end
