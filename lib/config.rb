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

    def email_to
      (ENV['EMAIL_TO'] || '').split(',').map(&:strip).reject(&:empty?)
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

    def db_path
      ENV['DB_PATH'] || './marketplace_monitor.db'
    end

    # Parse search configuration from environment variable
    # Format: query|lat|lng|min_price|max_price|[radius_km]|[condition]|[delivery_method]
    # Multiple searches separated by semicolons
    def search_config
      raw = ENV['SEARCHES'] || raise('SEARCHES not set in .env')
      raw.split(';').map do |search|
        parts = search.strip.split('|')
        {
          query: parts[0].strip,
          lat: parts[1].to_f,
          long: parts[2].to_f,
          min_price: parts[3].to_i,
          max_price: parts[4].to_i,
          radius_km: (parts[5] || 65).to_i,
          condition: parts[6]&.strip,
          delivery_method: parts[7]&.strip
        }
      end
    end

    # Parse duration strings like "30m", "2h", "1d" into seconds
    def parse_interval(interval_str)
      case interval_str
      when /^(\d+)m$/
        Regexp.last_match(1).to_i * 60
      when /^(\d+)h$/
        Regexp.last_match(1).to_i * 3600
      when /^(\d+)d$/
        Regexp.last_match(1).to_i * 86_400
      else
        30 * 60 # default to 30 minutes
      end
    end

    # Validate configuration
    def validate!
      errors = []
      errors << 'SOCIAVAULT_API_KEY not set' unless ENV['SOCIAVAULT_API_KEY']
      errors << 'EMAIL_TO not set or empty' if email_to.empty?
      errors << 'SEARCHES not set' unless ENV['SEARCHES']

      return unless errors.any?

      puts 'Configuration errors:'
      errors.each { |e| puts "  - #{e}" }
      raise 'Invalid configuration'
    end
  end
end
