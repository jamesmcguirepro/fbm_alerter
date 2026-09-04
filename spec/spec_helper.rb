# frozen_string_literal: true

require 'rspec'
require 'dotenv/load'
require_relative '../main'

ENV['RUBY_ENV'] = 'test'

ActiveRecord::Base.connection_pool.migration_context.migrate

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end
end

# Test environment setup
ENV['SOCIAVAULT_API_KEY'] = 'sk_test_key'
ENV['EMAIL_FROM'] = 'test@example.com'
ENV['EMAIL_TO'] = 'recipient@example.com'
ENV['SMTP_USERNAME'] = 'test_user'
ENV['SMTP_PASSWORD'] = 'test_pass'
ENV['DB_PATH'] = 'test_marketplace_monitor.db'
ENV['SEARCHES'] = 'bike|40.7128|-74.0060|100|500|25'
