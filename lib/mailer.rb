# frozen_string_literal: true

require 'mail'

# Wraps the Mail gem with a simple, testable interface
class Mailer
  class DeliveryError < StandardError; end

  class << self
    # Send a single email
    # @param from [String] Sender email address
    # @param to [String] Recipient email address
    # @param subject [String] Email subject line
    # @param html_body [String] HTML email body
    # @raise [DeliveryError] If email delivery fails
    def send_email(from:, to:, subject:, html_body:)
      ensure_configured

      mail = build_mail(from:, to:, subject:, html_body:)
      mail.deliver!
    rescue StandardError => e
      raise DeliveryError, "Failed to send email to #{to}: #{e.message}"
    end

    private

    def ensure_configured
      @_configured ||= configure_smtp
    end

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
      true
    end

    def build_mail(from:, to:, subject:, html_body:)
      Mail.new do
        from from
        to to
        subject subject
        html_part do
          content_type 'text/html; charset=UTF-8'
          body html_body
        end
      end
    end
  end
end