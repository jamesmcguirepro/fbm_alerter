# frozen_string_literal: true

require 'rspec'
require_relative '../../lib/config'
require_relative '../../lib/mailer'

RSpec.describe Mailer do
  before do
    Mailer.instance_variable_set(:@_configured, nil)

    # # Stub Config
    # stub_const("Config", class_double(
    #   Config,
    #   smtp_address: 'smtp.example.com',
    #   smtp_port: 587,
    #   smtp_username: 'user',
    #   smtp_password: 'pass',
    #   email_from: 'noreply@example.com'
    # ))
  end

  describe '.send_email' do
    it 'delivers the email' do
      allow_any_instance_of(Mail::Message).to receive(:deliver!)

      expect do
        Mailer.send_email(
          from: 'sender@example.com',
          to: 'recipient@example.com',
          subject: 'Test',
          html_body: '<p>Test</p>'
        )
      end.not_to raise_error
    end

    it 'raises DeliveryError when delivery fails' do
      allow_any_instance_of(Mail::Message).
        to receive(:deliver!).
        and_raise(StandardError, 'SMTP connection failed')

      expect do
        Mailer.send_email(
          from: 'sender@example.com',
          to: 'recipient@example.com',
          subject: 'Test',
          html_body: '<p>Test</p>'
        )
      end.to raise_error(Mailer::DeliveryError, /SMTP connection failed/)
    end

    it 'includes recipient email in error message' do
      allow_any_instance_of(Mail::Message).to receive(:deliver!)
                                                .and_raise(StandardError, 'Network error')

      expect do
        Mailer.send_email(
          from: 'sender@example.com',
          to: 'bad@example.com',
          subject: 'Test',
          html_body: '<p>Test</p>'
        )
      end.to raise_error(Mailer::DeliveryError, /bad@example.com/)
    end
  end
end