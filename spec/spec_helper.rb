# frozen_string_literal: true

# IMPORTANT: select the test database BEFORE anything loads .env or the app.
# Ordering matters because dotenv sets RUBY_ENV=development from .env, and the
# DB connection is established during the app require. If this runs late, tests
# connect to (and DatabaseCleaner truncates) the DEVELOPMENT database.
ENV['RUBY_ENV'] = 'test'

require 'database_cleaner/active_record'
require 'dotenv/load'
require 'rspec'
require 'timecop'
require 'webmock/rspec'
require_relative '../main'

ActiveRecord::Base.connection_pool.migration_context.migrate

# Guard: never let specs point at (and truncate) the development database.
connected_db = ActiveRecord::Base.connection_db_config.database.to_s
unless connected_db.include?('test')
  raise "Refusing to run specs against non-test database: #{connected_db}. " \
        "Check that RUBY_ENV is set to 'test' before the app is required."
end

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.before(:suite) do
    DatabaseCleaner.strategy = :transaction
    DatabaseCleaner.clean_with(:truncation)
    WebMock.disable_net_connect!(allow_localhost: true)
  end

  config.before(:each) do
    DatabaseCleaner.start
    WebMock.reset!
  end

  config.after(:each) do
    DatabaseCleaner.clean
  end
end

# Test environment setup
ENV['SOCIAVAULT_API_KEY'] = 'sk_test_key'
ENV['EMAIL_FROM'] = 'test@example.com'
ENV['SMTP_USERNAME'] = 'test_user'
ENV['SMTP_PASSWORD'] = 'test_pass'
