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

      return unless errors.any?

      puts 'Configuration errors:'
      errors.each { |e| puts "  - #{e}" }
      raise 'Invalid configuration'
    end
  end
end
